---
layout: default
title: Description of Database Tables
---

## SQL Database Tables and Stored Procedures
-----------------------

Below are the data tables that you will find in either the `{{ site.db_name }}_R` or `{{ site.db_name }}_Py` databases after deployment.

<table class="table" >
	<thead>
		<tr>
			<th>Table</th>
			<th>Description</th>
		</tr>
	</thead>
	<tbody>
		<tr>
			<td>dbo.Label_Names</td>
            <td>Names associated with each of the 20 labels</td>
        </tr>
        <tr>
			<td>dbo.Metrics</td>
            <td>Metrics for the trained model</td>
        </tr>
        <tr>
			<td>dbo.Model</td>
            <td>Trained model</td>
        </tr>
        <tr>
			<td>dbo.News_Test</td>
            <td>News items in the test set</td>
        </tr>
        <tr>
			<td>dbo.News_To_Score</td>
            <td>News items to score</td>
        </tr>
        <tr>
			<td>dbo.News_Train</td>
            <td>News items for training the model</td>
        </tr>
    </tbody>
</table>

The following stored procedures are used in this solutions in either the `{{ site.db_name }}_R` or `{{ site.db_name }}_Py` databases:
<table class="table" >
	<thead>
		<tr>
			<th>Stored Procedure</th>
			<th>Description</th>
		</tr>
	</thead>
	<tbody>
	    <tr>
        <td>dbo.evaluate</td><td>Evaluates the performance of the model</td>
        </tr>
        <tr>
        <td>dbo.initial_Run_Once_R <br/> dbo.initial_Run_Once_Py</td><td>Runs the training workflow natively in SQL for this solution</td>
        </tr>
        <tr>
        <td>dbo.score</td><td>Creates features on the fly for the testing set and makes predictions </td>
        </tr>
        <tr>
        <td>dbo.train_model</td><td>Creates features on the fly for the training set and train the multiclass logistic regression model</td>
        </tr>
        </tbody>
        </table>