-- Script to execute yourself the SQL Stored Procedures instead of using PowerShell. 

-- Pre-requisites: 
-- 1) The data should be already loaded with PowerShell (run Load_Data.ps1). 
-- 2) The stored procedures should be defined. Open the .sql files for steps 1,2,3 and run "Execute". 
-- 3) You should connect to the database in the SQL Server of the DSVM with:
-- Server Name: localhost
-- Integrated authentication is used

-- The default table names have been specified. You can modify them by changing the value of the parameters in what follows.

/* Set the working database to the one where you created the stored procedures */ 
Use NewsSQLPy
GO

DROP PROCEDURE IF EXISTS [dbo].[newsgroups]
GO

CREATE PROCEDURE [newsgroups] @input varchar(max), @output varchar(max), @model_key varchar(max)

AS 
BEGIN

	/* Step 1: Feature Engineering and Training */
	exec [dbo].[train_model] @model_key = 'LR';

	/* Step 2: Scoring on the testing set */ 
	exec [dbo].[score] @input = 'News_Test', @output = 'Predictions', @model_key = 'LR'

	/* Step 3: Evaluating the model */
	exec [dbo].[evaluate] @predictions_table = 'Predictions', @model_key = 'LR'

	/* Score an additonal data set */
	exec [dbo].[score] @input = 'News_To_Score', @output = 'Predictions_New', @model_key = 'LR'
;
END
GO

