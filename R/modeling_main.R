##########################################################################################################################################
## This R script will do the following:
## 1. Specify inputs: Full path of the input tables, SQL Server database name, User ID, Password, Server Name.
## 2. Apply the different steps: loading the data to SQL Server, text featurization, training, scoring, evaluating. 
##########################################################################################################################################

# Load library. 
library(RevoScaleR)
library(MicrosoftML)

# Set the working directory to the R scripts location.
# setwd()

##########################################################################################################################################
## SPECIFY INPUTS
##########################################################################################################################################

# Data sets full path. The paths below work if the working directory is set to the R scripts location. 
News_Train <- "../Data/News_Train"
News_Test <- "../Data/News_Test"
Label_Names <- "../Data/Label_Names"

# Creating the connection string. Specify:
## Database name. If it already exists, tables will be overwritten. If not, it will be created.
## Server name. If conecting remotely to the DSVM, the full DNS address should be used with the port number 1433 (which should be enabled) 
## User ID and Password. Change them below if you modified the default values.  
db_name <- "TextClassification_R"
server <- "localhost"

connection_string <- sprintf("Driver=SQL Server;Server=%s;Database=%s;Trusted_Connection=True", server, db_name)

##############################################################################################################################
## Set up connection to SQL Server 17 and create Database
##############################################################################################################################

# Open an Odbc connection with SQL Server master database only to create a new database with the rxExecuteSQLDDL function.
connection_string_master <- sprintf("Driver=SQL Server;Server=%s;Database=master;Trusted_Connection=True", server)
outOdbcDS_master <- RxOdbcData(table = "Default_Master", connectionString = connection_string_master)
rxOpen(outOdbcDS_master, "w")

# Create database if applicable. 
query <- sprintf( "if not exists(SELECT * FROM sys.databases WHERE name = '%s') CREATE DATABASE %s;", db_name, db_name)
rxExecuteSQLDDL(outOdbcDS_master, sSQLString = query)

# Close Obdc connection to master database. 
rxClose(outOdbcDS_master)

# Define SQL Compute Context for in-database computations. 
sql <- RxInSqlServer(connectionString = connection_string)

##############################################################################################################################
## Step 1: Load the data to SQL Server. 
##############################################################################################################################

# Set the compute context to local. 
rxSetComputeContext('local')

# Point to the txt data sets.
News_Train_text <- RxTextData(file = News_Train, delimiter = "\t")
News_Test_text <- RxTextData(file = News_Test, delimiter = "\t")
Label_Names_text <- RxTextData(file = Label_Names, delimiter = "\t")

# Point to the SQL tables where they will be written. 
News_Train_sql <- RxSqlServerData(table = "News_Train", connectionString = connection_string)
News_Test_sql <- RxSqlServerData(table = "News_Test", connectionString = connection_string)
Label_Names_sql <- RxSqlServerData(table = "Label_Names", connectionString = connection_string)

# Export them to SQL Server.
rxDataStep(inData = News_Train_text, outFile = News_Train_sql, overwrite = TRUE)
rxDataStep(inData = News_Test_text, outFile = News_Test_sql, overwrite = TRUE)
rxDataStep(inData = Label_Names_text, outFile = Label_Names_sql, overwrite = TRUE)

##############################################################################################################################
## Step 2: Create features on the fly for the training set and train the model.
##############################################################################################################################

# Get the factor levels of the label in the order of encounter based on the Id.
colInfo1 <- list()
colInfo1$Label$type <- "factor"
News_Train_sql1 <- RxSqlServerData(table = "News_Train", connectionString = connection_string, colInfo = colInfo1)
colInfo <- rxCreateColInfo(News_Train_sql1)

# Write the formula for training. 
## The Subject and Text are featurized separately in order to give to the words in the Subject the same weight as those in the Text. 
training_formula = "Label ~ SubjectPreprocessed + TextPreprocessed"

# Define the transformation to be used to generate features. 
# It will be applied on the fly during training and testing.
## Here, for each of the Subject and the Text separately, we: 
## - Remove stopwords, diacritics, punctuation and numbers.
## - Change capital letters to lower case. 
## - Hash the different words and characters. 
## The parameters or options can be further optimized by parameter sweeping.
## Other languages can be used.
text_transform_list <- list(featurizeText(vars = c(SubjectPreprocessed = "Subject",
                                                   TextPreprocessed = "Text"),
                                          language = "English", 
                                          stopwordsRemover = stopwordsDefault(), 
                                          case = "lower",
                                          keepDiacritics = FALSE, 
                                          keepPunctuations = FALSE, 
                                          keepNumbers = FALSE,  
                                          wordFeatureExtractor = ngramHash(ngramLength = 2, hashBits = 17, seed = 4),
                                          charFeatureExtractor = ngramHash(ngramLength = 3, hashBits = 17, seed = 4), 
                                          vectorNormalizer = "l2")) 

# Set the compute context to SQL for training. 
rxSetComputeContext(sql) 

# Point to the training set. 
News_Train_sql <- RxSqlServerData(table = "News_Train", connectionString = connection_string, colInfo = colInfo)

# Train the multiclass Logistic Regression Model.
logistic_model <- rxLogisticRegression(formula = training_formula,
                                       data = News_Train_sql,
                                       type = "multiClass",
                                       l2Weight = 1, 
                                       l1Weight = 1,
                                       mlTransforms = text_transform_list,
                                       trainThreads = 4)

# Save the model to SQL Server. 
rxSetComputeContext('local') 
## Open an Odbc connection with SQL Server.
OdbcModel <- RxOdbcData(table = "Model", connectionString = connection_string)
rxOpen(OdbcModel, "w")

## Drop the Model table if it exists. 
if(rxSqlServerTableExists(OdbcModel@table, OdbcModel@connectionString)) {
  rxSqlServerDropTable(OdbcModel@table, OdbcModel@connectionString)
}

## Create an empty Model table. 
rxExecuteSQLDDL(OdbcModel, 
                sSQLString = paste("CREATE TABLE [", OdbcModel@table, "] (",
                                   "[id] varchar(200) not null, ",
                                   "[value] varbinary(max) )",
                                   sep = "")
)

## Write the model to SQL. 
rxWriteObject(OdbcModel, "LR", logistic_model)

## Close the Obdc connection used. 
rxClose(OdbcModel)

# Set the compute context back to SQL. 
rxSetComputeContext(sql) 

##############################################################################################################################
## Step 3: Create features on the fly for the testing set, make predictions, and evaluate the model.
##############################################################################################################################

# Point to the testing set. 
News_Test_sql <- RxSqlServerData(table = "News_Test", connectionString = connection_string, colInfo = colInfo)

# Make Predictions while featurizing the text variables separately on the fly.
# This will automatically use the same text transformation as in the training, encoded in logistic_model. 
Predictions_Intermediate_sql <- RxSqlServerData(table = "Predictions_Intermediate", connectionString = connection_string)

rxPredict(modelObject = logistic_model,
          outData = Predictions_Intermediate_sql,
          data = News_Test_sql,
          extraVarsToWrite = c("Label", "Id"),
          overwrite = TRUE)

# Join the Predictions table with the Label names to get the actual predicted labels.
Join_Query_sql <- RxSqlServerData(sqlQuery = "SELECT LabelNames, Predictions_Intermediate.*
                                  FROM Predictions_Intermediate INNER JOIN Label_Names 
                                  ON Predictions_Intermediate.PredictedLabel = Label_Names.Label", 
                                  connectionString = connection_string)

Predictions_sql <- RxSqlServerData(table = "Predictions", connectionString = connection_string, stringsAsFactors = TRUE)
rxDataStep(inData = Join_Query_sql, outFile = Predictions_sql, overwrite = TRUE)

# Drop the intermediate table. 
rxSqlServerDropTable(table = "Predictions_Intermediate", connectionString = connection_string)

# Evaluate the model. 

## Confusion Matrix.
Confusion_Matrix <- rxCrossTabs(~ Label:PredictedLabel, Predictions_sql, returnXtabs = TRUE)

## Micro Average accuracy.
micro <- sum(diag(Confusion_Matrix))/sum(Confusion_Matrix)

## Macro Average accuracy.
macro <- mean(diag(Confusion_Matrix)/rowSums(Confusion_Matrix))

# Print the computed metrics.
metrics <- c("Micro Average Accuracy" = micro, 
             "Macro Average Accuracy" = macro)

print(metrics) 


##########################################################################################################################################
## Function to get the top n rows of a table stored on SQL Server.
## You can execute this function at any time during  your progress by removing the comment "#", and inputting:
##  - the table name.
##  - the number of rows you want to display.
##########################################################################################################################################

display_head <- function(table_name, n_rows){
  table_sql <- RxSqlServerData(sqlQuery = sprintf("SELECT TOP(%s) * FROM %s", n_rows, table_name), connectionString = connection_string)
  table <- rxImport(table_sql)
  print(table)
}

# table_name <- "insert_table_name"
# n_rows <- 10
# display_head(table_name, n_rows)


