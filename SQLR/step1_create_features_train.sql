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
	EXECUTE sp_execute_external_script @language = N'R',
									   @script = N' 

##########################################################################################################################################
##	Define the connection string and compute contexts.
##########################################################################################################################################
connection_string <- paste("Driver=SQL Server;Server=", server_name, ";Database=", database_name, ";Trusted_Connection=true;", sep="")
sql <- RxInSqlServer(connectionString = connection_string, num_tasks = 1)

##########################################################################################################################################
##	Get the column information.
##########################################################################################################################################
# Get the factor levels of the label.
colInfo1 <- list()
colInfo1$Label$type <- "factor"
News_Train_sql1 <- RxSqlServerData(table = "News_Train", connectionString = connection_string, colInfo = colInfo1)
colInfo <- rxCreateColInfo(News_Train_sql1)

# Set the compute context to SQL. 
rxSetComputeContext(sql) 

##########################################################################################################################################
##	Point to the training set and use the colInfo to specify the orders of the levels.
##########################################################################################################################################
# NOTE: When using sp_execute_external_script, it is also possible to use InputDataset in order to get a data frame containing the data below.
# RxSqlServerData is used instead of a data frame so that the data does not have to be entirely loaded into memory.

News_Train_sql <- RxSqlServerData(table = "News_Train",
								  connectionString = connection_string,
								  colInfo = colInfo)

##########################################################################################################################################
##	Specify the training formula.
##########################################################################################################################################
## The Subject and Text are featurized separately in order to give to the words in the Subject the same weight as those in the Text. 
training_formula = "Label ~ SubjectPreprocessed + TextPreprocessed"

##########################################################################################################################################
##	Specify the features that will be created on the fly while training.. 
##########################################################################################################################################
# Define the transformation to be used to generate features. 
## Here, for each of the Subject and the Text separately, we: 
## - Remove stopwords, diacritics, punctuation and numbers.
## - Change capital letters to lower case. 
## - Hash the different words and characters. 
## The parameters or options can be further optimized by parameter sweeping.
text_transform_list <- list(featurizeText(vars = c(SubjectPreprocessed = "Subject",
                                                   TextPreprocessed = "Text"),
                                          language = "English", 
                                          stopwordsRemover = stopwordsDefault(), 
                                          case = "lower",
                                          keepDiacritics = FALSE, 
                                          keepPunctuations = FALSE, 
                                          keepNumbers = FALSE,  
                                          wordFeatureExtractor = ngramHash(ngramLength = 2, hashBits = 17, seed = 4),
                                          charFeatureExtractor = ngramHash(ngramLength = 3, hashBits = 17, seed = 4), 
                                          vectorNormalizer = "l2")) 

##########################################################################################################################################
## Train a multiclass logistic regression model. 
##########################################################################################################################################
# Parameters of models have been chosen for illustrative purposes, and can be further optimized.

# Train a logistic regression model. 
logistic_model <- rxLogisticRegression(formula = training_formula,
                                       data = News_Train_sql,
                                       type = "multiClass",
                                       l2Weight = 1, 
                                       l1Weight = 1,
                                       mlTransforms = text_transform_list,
                                       trainThreads = 4)

##########################################################################################################################################
## Save the model to SQL Server. 
##########################################################################################################################################
# Set the compute context back to local for model uploading to SQL Server.
rxSetComputeContext("local")

# Serialize and write the model to SQL Server for future use. This is done by using an Odbc connection.
OdbcModel <- RxOdbcData(table = "Model", connectionString = connection_string)
rxOpen(OdbcModel, "w")
rxWriteObject(OdbcModel, model_key, logistic_model)
rxClose(OdbcModel)
'
, @params = N'@model_key varchar(max) , @server_name varchar(max), @database_name varchar(max)'
, @model_key = @model_key
, @server_name = @server_name
, @database_name = @database_name

;
END
GO

