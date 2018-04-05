---
layout: default
title: HOME
---

When a customer sends a support ticket, it is important to route it to the right team to examine the issue and solve it in the fastest way possible. This solution trains a model to classify text data.  It uses a preprocessed version of [NewsGroups20](http://scikit-learn.org/stable/datasets/twenty_newsgroups.html), containing a Subject (extracted from the raw text data), a Text, and a Label (20 classes). While this is not support ticket data, it has a similar structure to a support ticket data set which would also have two data fields: Title and Problem description.

The preprocessed training and testing sets are first uploaded to SQL Server. Text featurization is then defined. It consists of removing punctuation, diacritics, numbers, and predefined stopwords, then hashing the 2-gram words and 3-gram characters. The Subject and Text are featurized separately in order to give the words in the Subject as much weight as those in the Text, which is larger. Treating those two variables separately has proven to increase slightly the models predictive power in our experiments.

A multiclass logistic regression is then trained on the training set, which is featurized on the fly. The model is saved to SQL Server, and then used to make predictions on the testing set, which is also featurized on the fly at the time of the predictions. Finally, the model is evaluated through the computation of micro and macro average accuracy.

For customers who prefer an on-premise solution, the implementation with Microsoft Machine Learning Services is a great option that takes advantage of the powerful combination of SQL Server and the R and Python languages. We have modeled the steps in the template after a realistic team collaboration on a data science process. Data scientists do the data preparation, model training, and evaluation from their favorite IDE. DBAs can take care of the deployment using SQL stored procedures with embedded code.  We also show how each of these steps can be executed on a SQL Server client environment such as SQL Server Management Studio. A Windows PowerShell script that executes the end-to-end setup and modeling process is provided for convenience.

This solution starts with data stored in SQL Server.  The data scientist works from the convenience of an IDE on her client machine, while <a href="https://msdn.microsoft.com/en-us/library/mt604885.aspx">setting the computation context to SQL</a>.  When she is done, her code is operationalized as stored procedures in the SQL Database.

New data is scored using the `score` stored procedure in SQL.  You can view the predicted labels in the output table `Predicted_New`, or visualize both test and new data and predicted labels in the {{site.pbix_name}} file.

<img src="images/pbi2.png" />