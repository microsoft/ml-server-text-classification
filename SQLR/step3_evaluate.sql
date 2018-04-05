-- Stored Procedure to evaluate the models tested.

-- @predictions_table : name of the table that holds the predictions (output of scoring).
-- @model_key: key of the model to evaluate using the predictions table.

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [dbo].[evaluate]
GO

CREATE PROCEDURE [evaluate] @predictions_table varchar(max), @model_key varchar(max)

AS 
BEGIN

	-- Get the server and current database names.
	DECLARE @server_name varchar(max) = @@servername;
	DECLARE @database_name varchar(max) = db_name();

	-- Import the Predictions Table as an input to the Python code.
	DECLARE @inquery nvarchar(max) = N' SELECT * FROM ' + @predictions_table
	  
	INSERT INTO Metrics 
	EXECUTE sp_execute_external_script @language = N'R',
     								   @script = N' 

##########################################################################################################################################
## Model evaluation metrics.
##########################################################################################################################################
evaluate_model <- function(data, model_key){
	## Confusion matrix: 
	Confusion_Matrix <- rxCrossTabs(~ Label:PredictedLabel, data, returnXtabs = TRUE)

	## Micro Average accuracy: 
	micro <- sum(diag(Confusion_Matrix))/sum(Confusion_Matrix)

	## Macro Average accuracy: 
	macro <- mean(diag(Confusion_Matrix)/rowSums(Confusion_Matrix))

	metrics <- c(model_key, micro, macro)
	return(metrics)
}
##########################################################################################################################################
## Evaluation 
##########################################################################################################################################
OutputDataSet <- data.frame(rbind(evaluate_model(data = InputDataSet, model_key = model_key)))	
'
, @input_data_1 = @inquery
, @params = N'@predictions_table varchar(max), @model_key varchar(max), @server_name varchar(max), @database_name varchar(max)'	
, @model_key = @model_key
, @predictions_table = @predictions_table 
, @server_name = @server_name
, @database_name = @database_name
;
END
GO