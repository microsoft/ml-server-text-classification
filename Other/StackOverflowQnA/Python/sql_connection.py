##########################################################################################################################################
##	Import Modules
##########################################################################################################################################

import os 
import pyodbc
from revoscalepy import RxInSqlServer, RxLocalSeq

##########################################################################################################################################
##	Setting up connection to SQL Server 17
##########################################################################################################################################

# Specify the server name, database name, username, and password.
server_name = "localhost"
db_name = "QA"
username = "rdemo"
password = "D@tascience"

# Create the database if it does not already exist.
## Open a pyodbc connection to the master database to create db_name. 
connection_string_master = 'DRIVER={};SERVER={};DATABASE=master;UID={};PWD={}'.format("SQL Server", server_name, username, password)
cnxn_master = pyodbc.connect(connection_string_master, autocommit = True)
cursor_master = cnxn_master.cursor()
query_db = "if not exists(SELECT * FROM sys.databases WHERE name = '{}') CREATE DATABASE {}".format(db_name, db_name)
cursor_master.execute(query_db)

## Close the pyodbc connection to the master database. 
cursor_master.close()
del cursor_master
cnxn_master.close() 

# Write the connection string to the database db_name. 
connection_string = 'DRIVER={};SERVER={};DATABASE={};UID={};PWD={}'.format("SQL Server", server_name, db_name, username, password)

# Define compute contexts. 
sql = RxInSqlServer(connection_string = connection_string, num_tasks = 1)
local = RxLocalSeq()
