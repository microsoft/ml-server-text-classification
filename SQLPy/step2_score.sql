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
	EXECUTE sp_execute_external_script @language = N'Python',
     					               @script = N' 

##########################################################################################################################################
##	Import Modules.
##########################################################################################################################################
from revoscalepy import rx_set_compute_context, RxSqlServerData, RxOdbcData, rx_read_object, RxInSqlServer, rx_import
from microsoftml import rx_predict 

##########################################################################################################################################
##	Define the connection string.
##########################################################################################################################################
connection_string = "Driver=SQL Server;Server=" + server_name + ";Database=" + database_name + ";Trusted_Connection=true;"
sql = RxInSqlServer(connection_string = connection_string, num_tasks = 1)

##########################################################################################################################################
## Retrieve model.
##########################################################################################################################################
models_odbc = RxOdbcData(connection_string, table = "Model")
logistic_model = rx_read_object(models_odbc, key = model_key, deserialize = True)

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
##	Point to the testing set and use the factor_info dictionary to specify the types of the features.
##########################################################################################################################################
News_Test_sql = RxSqlServerData(table = input,
                                connection_string = connection_string,
                                column_info = factor_info)

##########################################################################################################################################
## Logistic Regresssion scoring.
##########################################################################################################################################
# Make Predictions while featurizing the text variables separately on the fly.
# This will automatically use the same text transformation as in the training, encoded in logistic_model.

# Set the Compute Context to SQL.
rx_set_compute_context(sql)

Predictions_Intermediate_sql = RxSqlServerData(table = "Predictions_Intermediate", connection_string = connection_string)

rx_predict(model = logistic_model,
           data = News_Test_sql,
		   output_data = Predictions_Intermediate_sql,
           extra_vars_to_write = ["Label", "Id"],
		   overwrite = True)
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

