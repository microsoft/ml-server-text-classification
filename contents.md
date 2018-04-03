---
layout: default
title: Template Contents
---

## Template Contents
--------------------

The following is the directory structure for this template:

- [**Data**](#data)  This contains Data for scoring.  Other data is downloaded during the solution workflow
- [**R**](#model-development-in-R)  This contains the R code to prepare training/testing/evaluation set, train the multi-class classifier and evaluate the model.
- [**Python**](#model-development-in-python)  This contains the Python code to prepare training/testing/evaluation set, train the multi-class classifier and evaluate the model.
- [**Resources**](#resources-for-the-solution-packet) This directory contains other resources for the solution package.




### Data
----------------------------

<table class="table table-striped table-condensed">
<tr><th> File </th><th> Description</th></tr>
<tr><th> File </th><th> Description </th></tr>
<tr><td>News_To_Score  </td><td> Text file containing new data for scoring. </td></tr>
</table>

### Model Development in Python
-------------------------

<table class="table table-striped table-condensed">
<tr><th> File </th><th> Description </th></tr>
<tr><td>TextClassificationR.ipynb  </td><td> Create features on the fly for the training and testing set, train model, make predictions, and evaluate the model in Jupyter notebook.</td></tr>
<tr><td>run_modeling_main.R  </td><td> Create features on the fly for the training and testing set, train model, make predictions, and evaluate the model.</td></tr>
</table>

* See [For the Data Scientist](data_scientist.html) for more details about these files.


### Operationalize in SQL R 
-------------------------------------------------------
Stored procedures in SQL implement the model training workflow with R code.

<table class="table table-striped table-condensed">
<tr><th> File </th><th> Description </th></tr> </td></tr>
<tr><td>Load_Data.ps1</td><td>Loads all data for the solution if you'd like to create a second instance of the solution on the same server</td></tr>
<tr><td>execute_yourself.sql</td><td>Runs through all the steps of the solution</td></tr>
<tr><td>step0_create_tables.sql</td><td>Create data tables, invoked in Load_Data.ps1</td></tr>
<tr><td>step1_create_features_train.sql</td><td>Create features on the fly and train model </td></tr>
<tr><td>step2_score.sql</td><td>Scores data with model created in step1 </td></tr>
<tr><td>step3_evaluate.sql</td><td>Evaluates model created in step1 </td></tr>
</table>

* See [ For the Database Analyst](dba.html) for more information.
* Follow the [PowerShell Instructions](Powershell_Instructions.html) to execute the PowerShell script which creates these stored procedures.

### Model Development in Python
-------------------------

<table class="table table-striped table-condensed">
<tr><th> File </th><th> Description </th></tr>
<tr><td>TextClassificationR.ipynb  </td><td> Create features on the fly for the training and testing set, train model, make predictions, and evaluate the model in Jupyter notebook.</td></tr>
<tr><td>run_modeling_main.py  </td><td> Create features on the fly for the training and testing set, train model, make predictions, and evaluate the model.</td></tr>
</table>


* See [For the Data Scientist](data_scientist.html) for more details about these files.


### Operationalize in SQL Python 
-------------------------------------------------------
Stored procedures in SQL implement the model training workflow with Python code.

<table class="table table-striped table-condensed">
<tr><th> File </th><th> Description </th></tr> </td></tr>
<tr><td>Load_Data.ps1</td><td>Loads all data for the solution if you'd like to create a second instance of the solution on the same server</td></tr>
<tr><td>execute_yourself.sql</td><td>Runs through all the steps of the solution</td></tr>
<tr><td>step0_create_tables.sql</td><td>Create data tables, invoked in Load_Data.ps1</td></tr>
<tr><td>step1_create_features_train.sql</td><td>Create features on the fly and train model </td></tr>
<tr><td>step2_score.sql</td><td>Scores data with model created in step1 </td></tr>
<tr><td>step3_evaluate.sql</td><td>Evaluates model created in step1 </td></tr>
</table>

* See [ For the Database Analyst](dba.html) for more information.
* Follow the [PowerShell Instructions](Powershell_Instructions.html) to execute the PowerShell script which creates these stored procedures.

### Resources for the Solution Package
------------------------------------

<table class="table table-striped table-condensed">
<tr><th> File </th><th> Description </th></tr>

<tr><td> .\Resources\ActionScripts\ConfigureSQL.ps1</td><td>Configures SQL, called from SetupVM.ps1  </td></tr>
<tr><td> .\Resources\ActionScripts\CreateDatabase.sql</td><td>Creates the database for this solution, called from ConfigureSQL.ps1  </td></tr>
<tr><td> .\Resources\ActionScripts\CreateSQLObjectsPy.sql</td><td>Creates the tables and stored procedures for this solution, called from ConfigureSQL.ps1   </td></tr>
<tr><td> .\Resources\ActionScripts\CreateSQLObjectsR.sql</td><td>Creates the tables and stored procedures for this solution, called from ConfigureSQL.ps1   </td></tr>
<tr><td> .\Resources\ActionScripts\TextClassificationSetup.ps1</td><td>Configures SQL, creates and populates database</td></tr>
<tr><td> .\Resources\ActionScripts\SolutionHelp.url</td><td>URL to the help page </td></tr>

</table>




[&lt; Home](index.html)
