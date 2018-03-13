##########################################################################################################################################
##	Import modules.
##########################################################################################################################################

from revoscalepy import rx_set_compute_context
from microsoftml import featurize_text, n_gram_hash, rx_logistic_regression, rx_predict
from microsoftml.entrypoints._stopwordsremover_predefined import predefined
from sklearn import metrics
from sklearn.metrics import confusion_matrix, classification_report

# Set the compute context to SQL. 
rx_set_compute_context(sql)

##########################################################################################################################################
##	Get the factor levels of the label
##########################################################################################################################################

# Get the factor levels of the label in the order of encounter based on the Id. 
Factors_sql = RxSqlServerData(sql_query = "SELECT AnswerId, min(Id) AS [Order] FROM QA_Train GROUP BY AnswerId ORDER BY min(Id)",
                              connection_string = connection_string)

levels_list  = list(rx_import(Factors_sql)['AnswerId'])

# Write the factor name and levels into a dictionary.
factor_info = {'AnswerId':{'type' : 'factor', 'levels' : [str(s) for s in levels_list]}}

##########################################################################################################################################
##	Create features on the fly and train the model.
##########################################################################################################################################

# Write the formula for training. 
training_formula = "AnswerId ~ TextPreprocessed"

# Point to the training set.
QA_Train_sql = RxSqlServerData(sql_query = "SELECT * FROM QA_Train ORDER BY Id", 
                               connection_string = connection_string,
                               column_info = factor_info)

# Define the transformation to be used to generate features.
text_transform_list =[featurize_text(cols = dict(TextPreprocessed = "Text"), 
                                     language = "English",
                                     stopwords_remover = predefined(),
                                     case = "Lower",
                                     keep_diacritics  = False,                                                   
                                     keep_punctuations = False,
                                     keep_numbers = True,
                                     word_feature_extractor = n_gram_hash(hash_bits = 13, ngram_length = 1),
                                     char_feature_extractor = n_gram_hash(hash_bits = 13, ngram_length = 3),
                                     vector_normalizer = "L2")]

# Train the logistic regression model. 
logistic_model = rx_logistic_regression(formula = training_formula,
                                        data = QA_Train_sql,
                                        method = "multiClass",
                                        ml_transforms = text_transform_list, 
                                        train_threads = 4)

##########################################################################################################################################
##	Make predictions on the testing set.
##########################################################################################################################################

# Point to the testing set.
QA_Test_sql = RxSqlServerData(table = "QA_Test",
                              connection_string = connection_string,
                              column_info = factor_info)

# Make predictions. 
Predictions_df = rx_predict(model = logistic_model,
                            data = QA_Test_sql,
                            extra_vars_to_write = ["AnswerId"])

##########################################################################################################################################
##	Evaluate the model. 
##########################################################################################################################################

Conf_Matrix = confusion_matrix(y_true = Predictions_df["AnswerId"], y_pred = Predictions_df["PredictedLabel"])

# Compute Evaluation Metrics. 
## Micro Average accuracy: 
sum(Conf_Matrix[i][i] for i in range(Conf_Matrix.shape[0]))/Predictions_df.shape[0]

## Macro Average accuracy:
sum(Conf_Matrix[i][i]/(sum(Conf_Matrix[i][j] for j in range(Conf_Matrix.shape[0]))) for i in range(Conf_Matrix.shape[0]))/Conf_Matrix.shape[0]

## Per-class precision, recall and F1-score. 
results = classification_report(y_true = Predictions_df["AnswerId"], y_pred = Predictions_df["PredictedLabel"])
print(results)


