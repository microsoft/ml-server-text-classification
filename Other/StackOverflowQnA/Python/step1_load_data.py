##########################################################################################################################################
##	Import Modules
##########################################################################################################################################

from revoscalepy import RxSqlServerData, RxTextData, rx_data_step, rx_set_compute_context

##########################################################################################################################################
##	Export the data to SQL Server 
##########################################################################################################################################
rx_set_compute_context(local)

# Point to the training and testing sets. 
QA_Train_text = RxTextData(file = "C:\\Users\\rdemo\\Desktop\\QA_text\\Data\\trainQsm", delimiter = "\t")
QA_Test_text = RxTextData(file = "C:\\Users\\rdemo\\Desktop\\QA_text\\Data\\testQsm", delimiter = "\t")

# Export to sql
QA_Train_sql = RxSqlServerData(table = "QA_Train", connection_string = connection_string)
rx_data_step(input_data = QA_Train_text, output_file = QA_Train_sql, overwrite = True)

QA_Test_sql = RxSqlServerData(table = "QA_Test", connection_string = connection_string)
rx_data_step(input_data = QA_Test_text, output_file = QA_Test_sql, overwrite = True)























