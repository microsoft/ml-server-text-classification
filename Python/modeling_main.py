##########################################################################################################################################
##	Import Modules
##########################################################################################################################################
import os 
import pyodbc
from sklearn import metrics
from sklearn.metrics import confusion_matrix, classification_report

from revoscalepy import RxInSqlServer, RxLocalSeq, RxSqlServerData, RxOdbcData, RxTextData
from revoscalepy import rx_set_compute_context, rx_data_step, rx_import, rx_write_object
from microsoftml import rx_logistic_regression, featurize_text, n_gram_hash, rx_predict
from microsoftml.entrypoints._stopwordsremover_predefined import predefined

# Set the working directory to the Python scripts location.
# os.chdir("path")

##########################################################################################################################################
## SPECIFY INPUTS
##########################################################################################################################################

# Data sets folder.
file_path = "..\\Data"

# Creating the connection string. Specify:
## Database name. If it already exists, tables will be overwritten. If not, it will be created.
## Server name. If conecting remotely to the DSVM, the full DNS address should be used with the port number 1433 (which should be enabled) 
## User ID and Password. Change them below if you modified the default values.  
server_name = "localhost"
db_name = "text_Py"


connection_string = 'DRIVER={};SERVER={};DATABASE={};TRUSTED_CONNECTION=True'.format("SQL Server", server_name, db_name)

##########################################################################################################################################
##	Set up connection to SQL Server 17 and Create Database
##########################################################################################################################################

# Create the database if it does not already exist.
## Open a pyodbc connection to the master database to create db_name. 
connection_string_master = 'DRIVER={};SERVER={};DATABASE=master;TRUSTED_CONNECTION=True'.format("SQL Server", server_name)
cnxn_master = pyodbc.connect(connection_string_master, autocommit = True)
cursor_master = cnxn_master.cursor()
query_db = "if not exists(SELECT * FROM sys.databases WHERE name = '{}') CREATE DATABASE {}".format(db_name, db_name)
cursor_master.execute(query_db)

## Close the pyodbc connection to the master database. 
cursor_master.close()
del cursor_master
cnxn_master.close() 

# Define compute contexts. 
sql = RxInSqlServer(connection_string = connection_string, num_tasks = 1)
local = RxLocalSeq()

##########################################################################################################################################
##	Export the data to SQL Server 
##########################################################################################################################################

# Set the compute context to local to export the data to SQL Server. 
rx_set_compute_context(local)

# Point to the txt data sets.
News_Train_text = RxTextData(file = os.path.join(file_path, "News_Train"), delimiter = "\t")
News_Test_text = RxTextData(file = os.path.join(file_path, "News_Test"), delimiter = "\t")
Label_Names_text = RxTextData(file = os.path.join(file_path, "Label_Names"), delimiter = "\t")

# Point to the SQL tables where they will be written. 
News_Train_sql = RxSqlServerData(table = "News_Train", connection_string = connection_string)
News_Test_sql = RxSqlServerData(table = "News_Test", connection_string = connection_string)
Label_Names_sql = RxSqlServerData(table = "Label_Names", connection_string = connection_string)

# Export them to SQL Server.
rx_data_step(input_data = News_Train_text, output_file = News_Train_sql, overwrite = True)
rx_data_step(input_data = News_Test_text, output_file = News_Test_sql, overwrite = True)
rx_data_step(input_data = Label_Names_text, output_file = Label_Names_sql, overwrite = True)

##########################################################################################################################################
##	Get the factor levels of the label
##########################################################################################################################################

# Get the factor levels of the label.
Factors_sql = RxSqlServerData(sql_query = "SELECT DISTINCT Label FROM News_Train",
                              connection_string = connection_string)

levels_list  = list(rx_import(Factors_sql)['Label'])

# Write the factor name and levels into a dictionary.
factor_info = {'Label':{'type' : 'factor', 'levels' : [str(s) for s in levels_list]}}

##########################################################################################################################################
##	Create features on the fly for the training set and train the model
##########################################################################################################################################

# Set the compute context to SQL for training.
rx_set_compute_context(sql)

# Write the formula for training. 
## The Subject and Text are featurized separately in order to give to the words in the Subject the same weight as those in the Text. 
training_formula = "Label ~ SubjectPreprocessed + TextPreprocessed"

# Define the transformation to be used to generate features.
# It will be applied on the fly during training and testing.
## Here, for each of the Subject and the Text separately, we: 
## - Remove stopwords, diacritics, punctuation and numbers.
## - Change capital letters to lower case. 
## - Hash the different words and characters. 
## The parameters or options can be further optimized by parameter sweeping.
## Other languages can be used.
text_transform_list =[featurize_text(cols = dict(SubjectPreprocessed = "Subject", TextPreprocessed = "Text"), 
                                     language = "English",
                                     stopwords_remover = predefined(),
                                     case = "Lower",
                                     keep_diacritics  = False,                                                   
                                     keep_punctuations = False,
                                     keep_numbers = False,
                                     word_feature_extractor = n_gram_hash(hash_bits = 17, ngram_length = 2, seed = 4),
                                     char_feature_extractor = n_gram_hash(hash_bits = 17, ngram_length = 3, seed = 4),
                                     vector_normalizer = "L2")]

# Point to the training set.
News_Train_sql = RxSqlServerData(table = "News_Train",
                                 connection_string = connection_string,
                                 column_info = factor_info)

# Train the model. 
logistic_model = rx_logistic_regression(formula = training_formula,
                                        data = News_Train_sql,
                                        method = "multiClass",
                                        l2_weight = 1, 
                                        l1_weight = 1,
                                        ml_transforms = text_transform_list,
                                        train_threads = 4)

# Serialize and save the model to SQL Server. 
rx_set_compute_context(local)
models_odbc = RxOdbcData(connection_string, table = "Model")
rx_write_object(models_odbc, key = "LR", value = logistic_model, serialize = True, overwrite = True)

# Set the Compute Context back to SQL.
rx_set_compute_context(sql)

##########################################################################################################################################
##	 Create features on the fly for the testing set, make predictions, and evaluate the model
##########################################################################################################################################

# Point to the testing set. 
News_Test_sql = RxSqlServerData(table = "News_Test",
                                connection_string = connection_string,
                                column_info = factor_info)

# Make Predictions while featurizing the text variables separately on the fly.
# This will automatically use the same text transformation as in the training, encoded in logistic_model.
Predictions_Intermediate_sql = RxSqlServerData(table = "Predictions_Intermediate", connection_string = connection_string)

rx_predict(model = logistic_model,
           data = News_Test_sql,
		   output_data = Predictions_Intermediate_sql,
           extra_vars_to_write = ["Label", "Id"],
		   overwrite = True)

# Get the real label names.
Join_Query_sql = RxSqlServerData(sql_query = "SELECT LabelNames, Predictions_Intermediate.* \
                                              FROM Predictions_Intermediate INNER JOIN Label_Names \
                                              ON Predictions_Intermediate.PredictedLabel = Label_Names.Label", 
                                connection_string = connection_string)

Predictions_sql = RxSqlServerData(table = "Predictions", connection_string = connection_string, strings_as_factors = True)
rx_data_step(input_data = Join_Query_sql, output_file = Predictions_sql, overwrite = True)

# Evaluate the model. 
Predictions_df = rx_import(Predictions_sql)
Conf_Matrix = confusion_matrix(y_true = Predictions_df["Label"], y_pred = Predictions_df["PredictedLabel"])

# Compute Evaluation Metrics. 
## Micro Average accuracy: 
micro = sum(Conf_Matrix[i][i] for i in range(Conf_Matrix.shape[0]))/Predictions_df.shape[0]
print("Micro Average Accuracy is {}".format(micro))

## Macro Average accuracy:
macro = sum(Conf_Matrix[i][i]/(sum(Conf_Matrix[i][j] for j in range(Conf_Matrix.shape[0]))) for i in range(Conf_Matrix.shape[0]))/Conf_Matrix.shape[0]
print("Macro Average Accuracy is {}".format(macro))

## Per-class precision, recall and F1-score. 
results = classification_report(y_true = Predictions_df["Label"], y_pred = Predictions_df["PredictedLabel"])
print(results)

##########################################################################################################################################
## Function to get the top n rows of a table stored on SQL Server.
## You can execute this function at any time during  your progress by removing the comment "#", and inputting:
##  - the table name.
##  - the number of rows you want to display.
##########################################################################################################################################
def display_head(table_name, n_rows):
    Table_sql = RxSqlServerData(sql_query = "SELECT TOP({}) * FROM {}".format(n_rows, table_name), connection_string = connection_string)
    Table_df = rx_import(Table_sql)
    print(Table_df)

display_head(table_name = "Predictions", n_rows = 10)