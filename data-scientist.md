---
layout: default
title: For the images Scientist
---

## For the Data Scientist - Develop with R or Python
----------------------------

<div class="row">
    <div class="col-md-6">
        <div class="toc">
            <li><a href="#first">{{ site.solution_name }}</a></li>
            <li><a href="#system-requirements">System Requirements</a></li>
            <li><a href="#data">Data</a></li>
            <li><a href="#workflow">Workflow</a></li>
            <ul>
                <li><a href="#step1">Step 1: Loading the data to SQL Server     </a></li>
                <li><a href="#step2">Step 2: Create features on the fly for the training set and train the model</a></li>
                <li><a href="#step3">Step 3: Create features on the fly for the testing set, make predictions, and evaluate the model</a></li>
            </ul>
            <li><a href="#step4">Visualize the results</a></li>
            <li><a href="#template-contents">Template Contents</a></li>

        </div>
    </div>
    <div class="col-md-6">
        Microsoft Machine Learning Services provide an extensible, scalable platform for integrating machine learning tasks and tools with the applications that consume machine learning services. It includes a database service that runs outside the SQL Server process and communicates securely with R and Python.
        <p>
       This solution package shows how to pre-process data (cleaning and feature engineering), train prediction models, and perform scoring on the SQL Server machine in either R or Python.</p>
    </div>
</div>

When a customer sends a support ticket, it is important to route it to the right team in order to examine the issue and solve it in the fastest way possible. We use sample data containing a Subject, a Text, and a Label to build a machine learning model that can predict a label for new incoming data.

This solution takes advantage of the power of SQL Server and RevoScaleR and RevoScalePy. The tables are all stored in a SQL Server, and most of the computations are done by loading chunks of data in-memory instead of the whole dataset.

All these steps can be executed in a R or Python IDE, and are then operationalized into SQL Server Stored Procedures.  Scoring of new data is then performed in SQL Server.

Scientists who are testing and developing solutions can work from the convenience of their preferred IDE on their client machine, while <a href="https://msdn.microsoft.com/en-us/library/mt604885.aspx">setting the computation context to SQL</a> (see  **R** or **Python** folder for code).  They can also deploy the completed solutions to SQL Server 2017 by embedding calls to R or Python in stored procedures. These solutions can then be further automated by the use of SQL Server Integration Services and SQL Server agent: a PowerShell script (.ps1 file) automates the running of the SQL code.

<a name="first"></a>

## {{ site.solution_name }}
--------------------------

To try this out yourself, see the [Quick Start](quick.html) section on the main page.

This page describes what happens in each of the steps.


## System Requirements
--------------------------

    {% include requirements.md %}

This code was tested using SQL Server 2017, and assumes that SQL Server with ML Services was installed. The installation process can be found [here](setupSQL.html).

## Data
--------------------------

{% include inputdata.html %}

[Click here](tables.html) to view the SQL database tables created in this solution.

## Workflow

The file **R/modeling_main.R** or **Python/modeling_main.py** enables the user to define the input and perform all the steps. Inputs are: paths to the raw data files, database name, server name, username and password.
The database is created if necessary, and the connection string as well as the SQL compute context are defined.

The steps below describe the process which applies identically to the R or Python code.

<a name="step1"></a>

### Step 1: Loading the data to SQL Server
-------------------------

The NewsGroups20 data has already been downloaded and preprocessed in R and Python, then saved to disk. The raw data has been uploaded to SQL Server. It consists of:

* News_Train: Training set.
* News_Test: Testing set.
* Label_Names: Link between the Label integers and the Label names. 

The preprocessing consists of:

* Separating the Subject from the rest of the text in the text variable. This creates two separate text variables: "Subject" and "Text". In this context, the data set has a similar structure to a Support Ticket classification problem. 
* Remove unnecessary words or special characters ("\t", "\n" etc.). 
* Remove rows with an empty text body. 
* Add an Id variable. 

<a name="step2"></a>

### Step 2: Create features on the fly for the training set and train the model
------------------------

For feature engineering, we want to featurize the text variables in the data: Subject and Text. 
The Subject and Text are featurized separately in order to give to the words in the Subject the same weight as those in the Text. This approach is also applicable to Support ticket Classification problems.

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

<a name="step3"></a>

### Step 3: Create features on the fly for the testing set, make predictions, and evaluate the model 
-------------------------

In the same fashion, we call the prediction function on the testing set News_Test. It makes predictions while featurizing the text variables (Subject and Text) separately on the fly. This will automatically use the same text transformation as in the training, encoded in logistic_model. 

Once we get the predictions, we perform an inner join with the "Label_Names" table in order to get the names of the predicted labels. 

Finally, we compute performance metrics in order to evaluate the model for this multi-class classification problem.

* Micro Average Accuracy: It is the overall accuracy, which corresponds to the number of correct class predictions divided by the total number of observations in the testing set (ie. rate of correct classification). In this sense, performing poorly on some rare classes but very accurately predicting the rest might still give a good result. 
* Macro Average Accuracy: It corresponds to the average of the per-class accuracy. In this sense, it treats all the classes equally, even if some of the classes are rare. 

These two metrics should thus be analyzed together, especially in the case of class imbalances.

{% include finalsteps.md %}