 Text Classification Template in SQL Server with Python sevices
--------------------------
 * **Introduction**
 * **System Requirements**
 * **Workflow Automation**
 * **Step 0: Creating Tables**
 * **Step 1: Create features on the fly for the training set and train the model**
 * **Step 2: Create features on the fly for the testing set and make predictions**
 * **Step 3: Evaluate the model**

### Introduction
-------------------------

When a customer sends a support ticket, it is important to route it to the right team in order to examine the issue and solve it in the fastest way possible. This notebook uses a preprocessed version of the NewsGroups20, containing a Subject, a Text, and a Label (20 classes). It has a similar structure to a support ticket data set which would also haver two data fields: Title, and Problem description.

For businesses that prefers an on-prem solution, the implementation with SQL Server R Services is a great option, which takes advantage of the power of SQL Server and RevoScaleR (Microsoft R Server). In this template, we implemented all steps in SQL stored procedures: data preprocessing, and feature engineering are implemented in pure SQL, while models training, scoring and evaluation steps are implemented with SQL stored procedures with embedded R (Microsoft R Server) code. 

All the steps can be executed on SQL Server client environment (such as SQL Server Management Studio). We provide a Windows PowerShell script, NewsGroups.ps1, which invokes the SQL scripts and demonstrates the end-to-end modeling process.

### System Requirements
-----------------------

To run the scripts, it requires the following:
 * SQL server 2017 with RevoscalePy (version 9.2) and MicrosoftML (version 1.5.0) installed and configured;
 * The SQL user name and password, and the user is configured properly to execute Python scripts in-memory (see [create_user.sql](..\Resources\ActionScripts\create_user.sql)).
 * SQL Database for which the user has write permission and can execute stored procedures (see [create_user.sql](..\Resources\ActionScripts\create_user.sql)).
 * Implied authentication is enabled so a connection string can be automatically created in R codes embedded into SQL Stored Procedures.
 * For more information about SQL server 2016 and R service, please visit: https://docs.microsoft.com/en-us/sql/advanced-analytics/what-s-new-in-sql-server-machine-learning-services


### Workflow Automation
-------------------

We provide a Windows PowerShell script to demonstrate the end-to-end workflow. To learn how to run the script, open a PowerShell command prompt, navigate to the directory storing the PowerShell script and type:

    Get-Help .\SQLPy-NewsGroups.ps1

To invoke the PowerShell script, type:
(
    .\SQLPy-NewsGroups.ps1 -ServerName "Server Name" -DBName "Database Name" -username "" -password "" -dataPath         

You can also type .\SQLPy-NewsGroups.ps1, and PowerShell will prompt you for the different parameters. 

-ServerName: a good practice is to write "localhost". 
-username and -password: use rdemo and D@tascience2016 unless you changed them in create_user.sql. 
-dataPath: it is an optional argument that lets the user specify the path for the folder containing the data files. If not specified, the default path links to the Data folder in the parent directory. 


### Step 0: Creating Tables
-------------------------

In this step, we create four tables, “News_Train”, "News_Test", "News_To_Score", and "Label_Names" in a SQL Server database, and the data is uploaded to these tables using bcp command in PowerShell. This is done through either Load_Data.ps1 or through running the beginning of NewsGroups.ps1. 

In those PowerShell scripts, the python script "download_data.py" in the Data folder is executed. It downloads and preprocesses the data, then save it to disk. Data is then uploaded to the SQL Tables through a bcp command. 

**Related files:**

* step0_create_tables.sql

### Step 1: Create features on the fly for the training set and train the model
-------------------------

For feature engineering, we want to featurize the text variables in the data: Subject and Text. 
The Subject and Text are featurized separately in order to give to the words in the Subject the same weight as those in the Text. This approach is also applicable to Support Tiket Classification problems.

For each of the Subject and the Text separately, we: 
* Remove stopwords, diacritics, punctuation and numbers.
* Change capital letters to lower case. 
* Hash the different words and characters. 

The parameters or options can be further optimized by parameter sweeping.

This is done by following these steps:

1- Get the factor levels of the label in the order of encounter based on the Id, serialize them, and save them to SQL Server for future use.

2- Define the text transformation to be used to generate features, in the form of a list. It will be applied on the fly during training and testing.

3- Train a multiclass logistic regression on the training set, using the text transformation list.

The model trained is then serialized and saved to SQL Server for future use.

This is done through the stored procedure "[dbo].[train_model]".


**Related files:**

* step1_create_features_train.sql


### Step 2: Create features on the fly for the testing set and make predictions
-------------------------

In the same fashion, we call the prediction function on the testing set News_Test. It makes predictions while featurizing the text variables (Subject and Text) separately on the fly. This will automatically use the same text transformation as in the training, encoded in logistic_model. 

Once we get the predictions, we perform an inner join with the "Label_Names" table in order to get the names of the predicted labels. 

This is done through the stored procedure "[dbo].[score]". It takes as inputs the name of the table with the data set to score, and the name of the table that will hold the output predictions. 

**Related files:**

* step2_score.sql

### Step 3: Evaluate the model
-------------------------

Finally, we compute performance metrics in order to evaluate the model for this multi-class classification problem.

* Micro Average Accuracy: It is the overall accuracy, which corresponds to the number of correct class predictions divided by the total number of observations in the testing set (ie. rate of correct classification). In this sense, performing poorly on some rare classes but very accurately predicting the rest might still give a good result. 
* Macro Average Accuracy: It corresponds to the average of the per-class accuracy. In this sense, it treats all the classes equally, even if some of the classes are rare. 

These two metrics should thus be analyzed together, especially in the case of class imbalances.

This is done through the stored procedure "[dbo].[evaluate]", which takes as an input the name of the table holding the predictions. 

**Related files:**

* step3_evaluate.sql

After evaluating the model, predictions are made on a new data set, News_To_Score.
