from revoscalepy import rx_set_compute_context, rx_exec_by, RxLocalParallel
from microsoftml import rx_logistic_regression, featurize_text, n_gram_hash, rx_predict
from microsoftml.entrypoints._stopwordsremover_predefined import predefined
from sklearn import metrics
from sklearn.metrics import confusion_matrix
import matplotlib.pyplot as plt
t1=time.time()
# Set the compute context to SQL.
rx_set_compute_context(sql)

############################################################################################################################################################################################################
# Read factor levels from SQL Server. 
############################################################################################################################################################################################################

# Read the factor levels table from SQL Server. 
Factors_sql = RxSqlServerData(table = "Factors", connection_string = connection_string)
Factors_df = rx_import(Factors_sql)

# Convert the levels into a list of strings.
def parse(s):
    return s.split(";")
levels_list = Factors_df['FactorLevels'].apply(parse)

# Write the factors names and levels into a dictionary.
factor_info = {}
for i in range(len(levels_list)):
    factor_info[Factors_df['FactorName'][i]] = {}
    factor_info[Factors_df['FactorName'][i]]['type'] = 'factor'
    factor_info[Factors_df['FactorName'][i]]['levels'] = levels_list[i]

############################################################################################################################################################################################################
# Create features on the fly and train the model for label CST_1.
############################################################################################################################################################################################################

# Write the formula for training. 
training_formula = "CST_1 ~ TitlePreprocessed + ProblemPreprocessed + ErrorPreprocessed"

# Point to the training and testing sets.
Office_Train_sql = RxSqlServerData(sql_query = "SELECT SRId, CST_1, CST_2, ISNULL(title, '') AS title, ISNULL(problem, '') AS problem, ISNULL(error, '') AS error \
                                                FROM Office_Train \
                                                ORDER BY SRId",
                                   connection_string = connection_string,
                                   column_info = factor_info)

Office_Test_sql = RxSqlServerData(sql_query = "SELECT SRId, CST_1, CST_2, ISNULL(title, '') AS title, ISNULL(problem, '') AS problem, ISNULL(error, '') AS error \
                                               FROM Office_Test \
                                               ORDER BY SRId",
                                  connection_string = connection_string,
                                  column_info = factor_info)

# Define the transformation to be used to generate features.
text_transform_list =[featurize_text(cols = dict(TitlePreprocessed = "title", ProblemPreprocessed = "problem", ErrorPreprocessed = "error"), 
                                     language = "English",
                                     stopwords_remover = predefined(),
                                     case = "Lower",
                                     keep_diacritics  = False,                                                   
                                     keep_punctuations = False,
                                     keep_numbers = False,
                                     word_feature_extractor = n_gram_hash(hash_bits = 16, ngram_length = 1),
                                     vector_normalizer = "L2")]

# Train the model. 
logistic_model = rx_logistic_regression(formula = training_formula,
                                        data = Office_Train_sql,
                                        method = "multiClass",
                                        ml_transforms = text_transform_list)

# Make predictions on the testing set. The predicted label will be used to route each testing set observation to the appropriate learner built in the next section. 
Predictions_CST1_sql = RxSqlServerData(table = "Predictions_CST1",
                                      connection_string = connection_string)

rx_predict(model = logistic_model,
           data = Office_Test_sql,
           output_data = Predictions_CST1_sql,
           extra_vars_to_write = ["CST_1", "SRId"],
           overwrite = True)

# Evaluate the model to make sure it has a good performance. 
#Predictions = rx_import(Predictions_CST1_sql)

#Conf_Matrix = confusion_matrix(y_true = Predictions["CST_1"], y_pred = Predictions["PredictedLabel"])

# Average accuracy. 
#acc = metrics.precision_score(y_true = Predictions["CST_1"], y_pred = Predictions["PredictedLabel"], average='macro')  

# Per label results. 
#metrics.precision_recall_fscore_support(y_true = Predictions["CST_1"], y_pred = Predictions["PredictedLabel"], beta=0.5, average=None)

#import numpy as np
#import matplotlib.pyplot as plt
#ticks=np.linspace(0, 4,num=90)
#plt.imshow(Conf_Matrix, interpolation='none')
#plt.colorbar()
#plt.xticks(ticks,fontsize=6)
#plt.yticks(ticks,fontsize=6)
#plt.grid(True)
#plt.show()

############################################################################################################################################################################################################
# Train different models for label CST_2 based on prediction for CST_1.
############################################################################################################################################################################################################

# Import training set. 
Office_Train_df = rx_import(Office_Train_sql)

# Function to build models in parallel based on the value of the key CST_1.
def train_models(keys, data, text_transform_list, levels_list):
    from microsoftml import rx_logistic_regression
    from revoscalepy import rx_data_step
    df = rx_data_step(data)
    log_model = rx_logistic_regression(formula = "CST_2 ~ TitlePreprocessed + ProblemPreprocessed + ErrorPreprocessed",
                                       data = df,
                                       method = "multiClass",
                                       ml_transforms = text_transform_list, 
                                       train_threads = 1)
    return log_model

# Apply the function in parallel across the cores. 
rx_set_compute_context(RxLocalParallel())
logistic_models = rx_exec_by(input_data = Office_Train_df, keys = ["CST_1"], function = train_models, function_parameters = dict(text_transform_list = text_transform_list, levels_list = levels_list))

# Function to build models in parallel based on the value of the key CST_1.
def train_models(keys, data, text_transform_list, levels_list):
    from microsoftml import rx_logistic_regression
    from revoscalepy import rx_data_step
    df = rx_data_step(data)
    log_model = rx_logistic_regression(formula = "CST_2 ~ TitlePreprocessed + ProblemPreprocessed + ErrorPreprocessed",
                                       data = df,
                                       method = "multiClass",
                                       ml_transforms = text_transform_list)
    return log_model

# Apply the function in parallel across the cores. 
logistic_models = rx_exec_by(input_data = Office_Train_sql, keys = ["CST_1"], function = train_models, function_parameters = dict(text_transform_list = text_transform_list, levels_list = levels_list))





############################################################################################################################################################################################################
# Make predictions on the testing set based on the predictions with the first model. 
############################################################################################################################################################################################################

# Import testing set together with the predictions from the first model. 
Office_Test2_sql = RxSqlServerData(sql_query = "SELECT Office_Test.SRId, PredictedLabel AS PredictedCST_1, Office_Test.CST_1, CST_2, ISNULL(title, '') AS title, ISNULL(problem, '') AS problem, ISNULL(error, '') AS error \
                                                FROM Office_Test INNER JOIN Predictions_CST1 ON Office_Test.SRId = Predictions_CST1.SRId \
                                                ORDER BY SRId",
                                  connection_string = connection_string,
                                  column_info = factor_info)

Office_Test_df = rx_import(Office_Test2_sql)

# Function to score the testing set in parallel for different values of the key CST_1. 
def score_models(keys, data, logistic_models):
    from microsoftml import rx_predict
    from revoscalepy import rx_data_step
    df = rx_data_step(data)
    current_key = df["PredictedCST_1"][0]
    model = logistic_models._dataframe['result'][current_key]
    Predictions = rx_predict(model = model, 
                             data = df,
                             extra_vars_to_write = ["CST_1", "PredictedCST_1", "CST_2", "SRId"])
    return Predictions

# Apply the function in parallel across the cores. 
rx_set_compute_context(RxLocalParallel())
Final_Predictions = rx_exec_by(input_data = Office_Test_df, keys = ["PredictedCST_1"], function = score_models, function_parameters = dict(logistic_models = logistic_models))

# Combine the predictions together. 
cst1_list = levels_list[0]
Predictions_df = pd.DataFrame()
for cst1 in cst1_list:
    Predictions_df = pd.concat([Predictions_df, Final_Predictions._dataframe['result'][cst1]])


# Concatenate the 2 labels for the final evaluation. 
Predictions_df['Target'] = Predictions_df['CST_1'] + "-" + Predictions_df['CST_2']
Predictions_df['Target']  = Predictions_df['Target'] .astype('category')

Predictions_df['Prediction'] = Predictions_df['PredictedCST_1'] + "-" + Predictions_df['PredictedLabel']
Predictions_df['Prediction'] = Predictions_df['Prediction'] .astype('category')
t2=time.time()
############################################################################################################################################################################################################
# Final Evaluation.
############################################################################################################################################################################################################

# Confusion matrix. 
Conf_Matrix = confusion_matrix(y_true = Predictions_df['Target'], y_pred = Predictions_df['Prediction'])

# Compute Evaluation Metrics. 
from sklearn.metrics import accuracy_score
from sklearn.metrics import classification_report

## Average accuracy: 
sum(Conf_Matrix[i][i] for i in range(Conf_Matrix.shape[0]))/Predictions_df.shape[0]

## Per-class precision, recall and F1-score. 
results = classification_report(y_true = Predictions_df['Target'], y_pred = Predictions_df['Prediction'])

 
