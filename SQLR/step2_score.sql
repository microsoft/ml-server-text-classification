-- Stored Procedure to score a data set on a trained model stored in the Models table. 

-- @input: name of the table with the data to be scored. 
-- @output: name of the table that will hold the predictions. 
-- @model_key: key of the model to be used for scoring from the Model table.

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [dbo].[score]
GO

CREATE PROCEDURE [score] @input varchar(max), @output varchar(max), @model_key varchar(max)

AS 
BEGIN

	-- Get the server and current database names.
	DECLARE @server_name varchar(max) = @@servername;
	DECLARE @database_name varchar(max) = db_name();

	-- Compute the predictions. 
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

########################################################################################################################################## 
## Retrieve the trained model.
########################################################################################################################################## 
# Create an Odbc connection with SQL Server using the name of the table storing the model. 
OdbcModel <- RxOdbcData(table = "Model", connectionString = connection_string) 

# Read the model from SQL.  
logistic_model <- rxReadObject(OdbcModel, model_key)

# Set the Compute Context to SQL.
rxSetComputeContext(sql)

##########################################################################################################################################
##	Point to the testing set and use the colInfo to specify the orders of the levels.
##########################################################################################################################################
News_Test_sql <- RxSqlServerData(table = input,
                                 connectionString = connection_string,
                                 colInfo = colInfo)

##########################################################################################################################################
## Logistic Regresssion scoring.
##########################################################################################################################################
# Make Predictions while featurizing the text variables separately on the fly.
# This will automatically use the same text transformation as in the training, encoded in logistic_model.

Predictions_Intermediate_sql <- RxSqlServerData(table = "Predictions_Intermediate", connectionString = connection_string)

rxPredict(modelObject = logistic_model,
          data = News_Test_sql,
		  outData = Predictions_Intermediate_sql,
          extraVarsToWrite = c("Label", "Id"),
		  overwrite = TRUE)
'
, @params = N'@input varchar(max), @model_key varchar(max), @server_name varchar(max), @database_name varchar(max)'	  
, @input = @input
, @model_key = @model_key
, @server_name = @server_name
, @database_name = @database_name

-- Join the Predictions table with the Label names to get the actual predicted labels.
DECLARE @sql0 nvarchar(max);
SELECT @sql0 = N'
DROP TABLE if exists ' + @output 
EXEC sp_executesql @sql0

DECLARE @sql nvarchar(max);
SELECT @sql = N'
SELECT LabelNames, Predictions_Intermediate.*
INTO ' + @output +'
FROM Predictions_Intermediate INNER JOIN Label_Names 
ON Predictions_Intermediate.PredictedLabel = Label_Names.Label'
EXEC sp_executesql @sql

-- Drop the intermediate table. 
DROP TABLE Predictions_Intermediate;
;
END
GO
