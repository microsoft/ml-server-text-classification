Text Classification in SQL Server with Python sevices using Python IDE. 
--------------------------
 * **Introduction**
 * **System Requirements**
 * **Step 1: Loading the data to SQL Server**
 * **Step 2: Create features on the fly for the training set and train the model**
 * **Step 3: Create features on the fly for the testing set, make predictions, and evaluate the model**

### Introduction
-------------------------

When a customer sends a support tiket, it is important to route it to the right team in order to examine the issue and solve it in the fastest way possible. This notebook uses a preprocessed version of the NewsGroups20, containing a Subject, a Text, and a Label (20 classes). It has a similar structure to a support tiket data set which would also haver two data fields: Title, and Problem description.

This notebook takes advantage of the power of SQL Server and RevoScalePy. The tables are all stored in a SQL Server, and most of the computations are done by loading chunks of data in-memory instead of the whole dataset.

All these steps can be executed in a Python IDE. 

### System Requirements
-----------------------

To run the scripts, it requires the following:
 * R IDE with Microsoft R server installed and configured;
 * SQL server 2017 with RevoscalePy (version 9.2) and MicrosoftML (version 1.5.0) installed and configured;
 * The SQL user name and password;
 * SQL Database for which the user has write permission;
 * For more information about SQL server 2017 and Python service, please visit: https://docs.microsoft.com/en-us/sql/advanced-analytics/what-s-new-in-sql-server-machine-learning-services

The file "modeling_main.py" enables the user to define the input and perform all the steps. Inputs are: paths to the raw data files, database name, server name, username and password.
The database is created if not already existing, and the connection string as well as the SQL compute context are defined. 

### Step 1: Loading the data to SQL Server
-------------------------

The NewsGroups20 data has already been downloaded and preprocessed in Python, then saved to disk. The raw data are uploaded to SQL Server. It consists of:

- News_Train: Training set. 
- News_Test: Testing set.
- Label_Names: Link between the Label integers and the Label names. 

The preprocessing consists of: 
- Separating the Subject from the rest of the text in the text variable. This creates two separate text variables: "Subject" and "Text". In this context, the data set has a similar structure to a Support Ticket classification problem. 
- Remove unnecessary words or special characters ("\t", "\n" etc.). 
- Remove rows with an empty text body. 
- Add an Id variable. 


### Step 2: Create features on the fly for the training set and train the model
------------------------

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


### Step 3: Create features on the fly for the testing set, make predictions, and evaluate the model 
-------------------------

In the same fashion, we call the prediction function on the testing set News_Test. It makes predictions while featurizing the text variables (Subject and Text) separately on the fly. This will automatically use the same text transformation as in the training, encoded in logistic_model. 

Once we get the predictions, we perform an inner join with the "Label_Names" table in order to get the names of the predicted labels. 

Finally, we compute performance metrics in order to evaluate the model for this multi-class classification problem.

* Micro Average Accuracy: It is the overall accuracy, which corresponds to the number of correct class predictions divided by the total number of observations in the testing set (ie. rate of correct classification). In this sense, performing poorly on some rare classes but very accurately predicting the rest might still give a good result. 
* Macro Average Accuracy: It corresponds to the average of the per-class accuracy. In this sense, it treats all the classes equally, even if some of the classes are rare. 

These two metrics should thus be analyzed together, especially in the case of class imbalances.

