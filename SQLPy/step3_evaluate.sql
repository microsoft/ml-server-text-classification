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
	EXECUTE sp_execute_external_script @language = N'Python',
     								   @script = N' 

##########################################################################################################################################
##	Import Modules.
##########################################################################################################################################
from pandas import DataFrame
from collections import OrderedDict 
from sklearn import metrics
from sklearn.metrics import confusion_matrix

##########################################################################################################################################
## Model evaluation metrics.
##########################################################################################################################################
def evaluate_model(observed, predicted, model):
	## Confusion matrix: 
	Conf_Matrix = confusion_matrix(y_true = observed, y_pred = predicted)

	## Micro Average accuracy: 
	micro = sum(Conf_Matrix[i][i] for i in range(Conf_Matrix.shape[0]))/len(observed)

	## Macro Average accuracy: 
	macro = sum(Conf_Matrix[i][i]/(sum(Conf_Matrix[i][j] for j in range(Conf_Matrix.shape[0]))) for i in range(Conf_Matrix.shape[0]))/Conf_Matrix.shape[0]

	metrics = OrderedDict([ ("model_name", [model]),
				         ("avg_accuracy_micro", [micro]),
                         ("avg_accuracy_macro", [macro]) ])
	print(metrics)
	return(metrics)

##########################################################################################################################################
## Evaluation 
##########################################################################################################################################
evaluation = evaluate_model(observed = InputDataSet["Label"], predicted = InputDataSet["PredictedLabel"], model = model_key)
OutputDataSet = DataFrame.from_dict(evaluation)
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

