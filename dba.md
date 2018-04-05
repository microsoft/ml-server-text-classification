---
layout: default
title: For the Database Analyst
---

## For the Database Analyst - Operationalize with SQL
------------------------------

<div class="row">
    <div class="col-md-6">
        <div class="toc">
            <li><a href="#system-requirements">System Requirements</a></li>
            <li><a href="#workflow-automation">Workflow Automation</a></li>
            <ul>
                <li><a href="#step0">Step 0: Creating Tables</a></li>
                <li><a href="#step1">Step 1: Create features on the fly for the training set and train the model</a></li>
                <li><a href="#step2">Step 2: Create features on the fly for the testing set and make predictions</a></li>
                <li><a href="#step3">Step 3: Evaluate the model</a></li>
            </ul>
            <li><a href="#step4">Visualize the results</a></li>
            <li><a href="#template-contents">Template Contents</a></li>

        </div>
    </div>
    <div class="col-md-6">
              Microsoft Machine Learning Services provide an extensible, scalable platform for integrating machine learning tasks and tools with the applications that consume machine learning services. It includes a database service that runs outside the SQL Server process and communicates securely with R and Python.
        <p>
       This solution package shows how to pre-process data (cleaning and feature engineering), train prediction models, and perform scoring on the SQL Server machine with stored procedures which includes Python code.  </p>
          </div>
</div>
When a customer sends a support ticket, it is important to route it to the right team in order to examine the issue and solve it in the fastest way possible. We use sample data containing a Subject, a Text, and a Label to build a machine learning model that can predict a label for new incoming data.

This solution takes advantage of the power of SQL Server and RevoScaleR and RevoScalePy. The tables are all stored in a SQL Server, and most of the computations are done by loading chunks of data in-memory instead of the whole dataset.

All the steps can be executed on SQL Server client environment (SQL Server Management Studio). We provide a Windows PowerShell script which invokes the SQL scripts and demonstrates the end-to-end modeling process.

## System Requirements
-----------------------

    {% include requirements.md %}


## Workflow Automation
-------------------
Follow the [PowerShell instructions](Powershell_Instructions.html) to execute all the scripts described below.  [Click here](tables.html) to view the SQL database tables created in this solution.

The SQL Stored procedure `Initial_Run_Once_R` or `Initial_Run_Once_Py` `{{ site.db_name }}_R` or `{{ site.db_name }}_Py` database, respectively, can be used to re-run all the steps below

<a name="step0"></a>

### Step 0: Creating Tables
-------------------------

In this step, we create four tables, `News_Train`, `News_Test`, `News_To_Score`, and `Label_Names` in a SQL Server database, and the data is uploaded to these tables using bulkcopy process from PowerShell. 

In the PowerShell script, the python script "download_data.py" in the Data folder is executed. It downloads and preprocesses the data, then save it to disk. Data is then uploaded to the SQL Tables through a bulkcopy process.

<a name="step1"></a>

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

1. Get the factor levels of the label in the order of encounter based on the Id, serialize them, and save them to SQL Server for future use.

2. Define the text transformation to be used to generate features, in the form of a list. It will be applied on the fly during training and testing.

3. Train a multiclass logistic regression on the training set, using the text transformation list.

The model trained is then serialized and saved to SQL Server for future use.

**Example:**

    exec [dbo].[train_model] @model_key = 'LR';

<a name="step2"></a>

### Step 2: Create features on the fly for the testing set and make predictions
-------------------------

In the same fashion, we call the prediction function on the testing set News_Test. It makes predictions while featurizing the text variables (Subject and Text) separately on the fly. This will automatically use the same text transformation as in the training, encoded in logistic_model.

Once we get the predictions, we perform an inner join with the "Label_Names" table in order to get the names of the predicted labels.

This is done through the stored procedure "[dbo].[score]". It takes as inputs the name of the table with the data set to score, and the name of the table that will hold the output predictions.

**Example:**

    exec [dbo].[score] @input = 'News_Test', @output = 'Predictions', @model_key = 'LR'

<a name="step3"></a>

### Step 3: Evaluate the model
-------------------------

Finally, we compute performance metrics in order to evaluate the model for this multi-class classification problem.

* Micro Average Accuracy: It is the overall accuracy, which corresponds to the number of correct class predictions divided by the total number of observations in the testing set (ie. rate of correct classification). In this sense, performing poorly on some rare classes but very accurately predicting the rest might still give a good result.

* Macro Average Accuracy: It corresponds to the average of the per-class accuracy. In this sense, it treats all the classes equally, even if some of the classes are rare.

These two metrics should thus be analyzed together, especially in the case of class imbalances.

This is done through the stored procedure `[dbo].[evaluate]`, which takes as an input the name of the table holding the predictions.

**Example:**

    exec [dbo].[evaluate] @predictions_table = 'Predictions', @model_key = 'LR'

After evaluating the model, predictions are made on a new data set, News_To_Score.

**Example:**

    exec [dbo].[score] @input = 'News_To_Score', @output = 'Predictions_New', @model_key = 'LR'

These new records can be seen in the second tab of the PowerBI report. 

{% include finalsteps.md %}