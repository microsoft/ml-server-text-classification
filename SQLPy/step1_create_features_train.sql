-- Stored Procedure to create features on the fly for the training set, and train a multiclass logistic regression.

-- @model_key: unique key to be given to the trained model. If you want to train a new model, use a different key.

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [dbo].[train_model];
GO

CREATE PROCEDURE [train_model] @model_key varchar(max) 

AS 
BEGIN

	-- Get the server and current database names.
	DECLARE @server_name varchar(max) = @@servername;
	DECLARE @database_name varchar(max) = db_name();

	-- Train the model on the training set.	
	EXECUTE sp_execute_external_script @language = N'Python',
									   @script = N' 

##########################################################################################################################################
##	Import Modules.
##########################################################################################################################################
from revoscalepy import rx_set_compute_context, rx_import, RxOdbcData, rx_write_object, RxSqlServerData, RxInSqlServer, RxLocalSeq
from microsoftml import rx_logistic_regression, featurize_text, n_gram_hash, rx_predict
from microsoftml.entrypoints._stopwordsremover_predefined import predefined

##########################################################################################################################################
##	Define the connection string and compute contexts.
##########################################################################################################################################
connection_string = "Driver=SQL Server;Server=" + server_name + ";Database=" + database_name + ";Trusted_Connection=true;"

sql = RxInSqlServer(connection_string = connection_string, num_tasks = 1)
local = RxLocalSeq()

##########################################################################################################################################
##	Get the column information.
##########################################################################################################################################
# Get the factor levels of the label.
Factors_sql = RxSqlServerData(sql_query = "SELECT DISTINCT Label FROM News_Train",
                              connection_string = connection_string)
levels_list  = list(rx_import(Factors_sql)["Label"])

# Write the factor name and levels into a dictionary.
factor_info = {"Label":{"type" : "factor", "levels" : [str(s) for s in levels_list]}}

##########################################################################################################################################
##	Point to the training set and use the factor_info dictionary to specify the types of the features.
##########################################################################################################################################
# NOTE: When using sp_execute_external_script, it is also possible to use InputDataset in order to get a dataframe containing the data below.
# RxSqlServerData is used instead of a dataframe so that the data does not have to be entirely loaded into memory.

News_Train_sql = RxSqlServerData(table = "News_Train",
                                 connection_string = connection_string,
                                 column_info = factor_info)

##########################################################################################################################################
##	Specify the training formula.
##########################################################################################################################################
## The Subject and Text are featurized separately in order to give to the words in the Subject the same weight as those in the Text. 
training_formula = "Label ~ SubjectPreprocessed + TextPreprocessed"

##########################################################################################################################################
##	Specify the features that will be created on the fly while training.. 
##########################################################################################################################################
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

##########################################################################################################################################
## Train a multiclass logistic regression model and save it to SQL Server. 
##########################################################################################################################################
# Parameters of both models have been chosen for illustrative purposes, and can be further optimized.

# Set the compute context to SQL for the training. 
rx_set_compute_context(sql)

# Train a logistic regression model. 
logistic_model = rx_logistic_regression(formula = training_formula,
                                        data = News_Train_sql,
                                        method = "multiClass",
										l2_weight = 1, 
                                        l1_weight = 1,
                                        ml_transforms = text_transform_list,
                                        train_threads = 4)

# Set the compute context to local.
rx_set_compute_context(local)

# Write model to SQL Server.
models_odbc = RxOdbcData(connection_string, table = "Model")
rx_write_object(models_odbc, key = model_key, value = logistic_model, serialize = True, overwrite = True)
'
, @params = N'@model_key varchar(max) , @server_name varchar(max), @database_name varchar(max)'
, @model_key = @model_key
, @server_name = @server_name
, @database_name = @database_name
;
END
GO
