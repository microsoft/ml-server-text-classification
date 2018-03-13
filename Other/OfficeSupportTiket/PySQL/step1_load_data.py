##########################################################################################################################################
##	Import Modules
##########################################################################################################################################
from revoscalepy import RxSqlServerData, RxTextData, rx_import, rx_data_step

##########################################################################################################################################
##	Export the data to SQL Server 
##########################################################################################################################################

# Point to the training and testing sets. 
Office_Train_text = RxTextData(file = "C:\\Users\\rdemo\\Desktop\\Office\\Data\\Office.train.data.tsv", delimiter = "\t")
Office_Test_text = RxTextData(file = "C:\\Users\\rdemo\\Desktop\\Office\\Data\\Office.test.data.tsv", delimiter = "\t")

# Export to sql
Office_Train_sql = RxSqlServerData(table = "Office_Train", connection_string = connection_string)
rx_data_step(input_data = Office_Train_text, output_file = Office_Train_sql, overwrite = True)

Office_Test_sql = RxSqlServerData(table = "Office_Test", connection_string = connection_string)
rx_data_step(input_data = Office_Test_text, output_file = Office_Test_sql, overwrite = True)























