[CmdletBinding()]
param(
[parameter(Mandatory=$true, Position=1)]
[string]$ServerName,

[parameter(Mandatory=$true, Position=2)]
[string]$SolutionName,

[parameter(Mandatory=$true, Position=3)]
[string]$InstallPy,

[parameter(Mandatory=$true, Position=4)]
[string]$InstallR,

[parameter(Mandatory=$false, Position=5)]
[string]$Prompt
)

$Prompt = 'N'

$db = if ($Prompt -eq 'Y') {Read-Host  -Prompt "Enter Desired Database Base Name"} else {$SolutionName} 

$dataList = ("Label_Names", "News_Test", "News_To_Score", "News_Train")

$dataPath = "C:\Solutions\TextClassification\Data\"

##########################################################################

# Create Database and BaseTables 

#########################################################################

####################################################################
# Check to see If SQL Version is at least SQL 2017 and Not SQL Express 
####################################################################

$query = 
"select 
        case 
            when 
                cast(left(cast(serverproperty('productversion') as varchar), 4) as numeric(4,2)) >= 14 
                and CAST(SERVERPROPERTY ('edition') as varchar) Not like 'Express%' 
            then 'Yes'
        else 'No' end as 'isSQL17'"

$isCompatible = Invoke-Sqlcmd -ServerInstance $ServerName -Database Master -Query $query
$isCompatible = $isCompatible.Item(0)
if ($isCompatible -eq 'Yes' -and $InstallPy -eq 'Yes') 
    {
    Write-Host 
    ("This Version of SQL is Compatible with SQL Py")

    ## Create Py Database
    Write-Host 
    ("Creating SQL Database for Py")

    ## Create PY Server DB
    $dbName = $db + "_Py"
    $SqlParameters = @("dbName=$dbName")

    $CreateSQLDB = "$ScriptPath\CreateDatabase.sql"

    $CreateSQLObjects = "$ScriptPath\CreateSQLObjectsPy.sql"
    Write-Host 
    ("Calling Script to create the $dbName database") 
    invoke-sqlcmd -inputfile $CreateSQLDB -serverinstance $ServerName -database master -Variable $SqlParameters

    Write-Host 
    ("SQLServerDB $dbName Created")
    invoke-sqlcmd "USE $dbName;" 

    Write-Host 
    ("Calling Script to create the objects in the $dbName database")
    invoke-sqlcmd -inputfile $CreateSQLObjects -serverinstance $ServerName -database $dbName

    Write-Host 
    ("SQLServerObjects Created in $dbName Database")
    $OdbcName = "obdc" + $dbname
    ## Create ODBC Connection for PowerBI to Use 
    Add-OdbcDsn -Name $OdbcName -DriverName "ODBC Driver 13 for SQL Server" -DsnType 'System' -Platform '64-bit' -SetPropertyValue @("Server=$ServerName", "Trusted_Connection=Yes", "Database=$dbName") -ErrorAction SilentlyContinue -PassThru
    
}
else 
    {
    if ($isCompatible -eq 'Yes' -and $InstallPy -eq 'Yes') 
        {
        Write-Host 
        ("This Version of SQL is not compatible with Py , Py Code and DB's will not be Created")}
    else 
        {
        Write-Host 
        ("There is not a py version of this solution")
        }
    }

 


If ($InstallR -eq 'Yes')
    {
    Write-Host 
    ("Creating SQL Database for R")

    $dbName = $db + "_R"

    ## Create RServer DB 
    $SqlParameters = @("dbName=$dbName")

    $CreateSQLDB = "$ScriptPath\CreateDatabase.sql"

    $CreateSQLObjects = "$ScriptPath\CreateSQLObjectsR.sql"
    Write-Host 
    ("Calling Script to create the  $dbName database") 
    invoke-sqlcmd -inputfile $CreateSQLDB -serverinstance $ServerName -database master -Variable $SqlParameters

    Write-Host 
    ("SQLServerDB $dbName Created")
    invoke-sqlcmd "USE $dbName;" 

    Write-Host 
    ("Calling Script to create the objects in the $dbName database")   
    invoke-sqlcmd -inputfile $CreateSQLObjects -serverinstance $ServerName -database $dbName

    Write-Host 
    ("SQLServerObjects Created in $dbName Database")

###Configure Database for R 
    Write-Host 
    ("Configuring $SolutionName Solution for R")

$dbName = $db + "_R" 

## Create ODBC Connection for PowerBI to Use 
    $OdbcName = "obdc" + $dbname
## Create ODBC Connection for PowerBI to Use 
    Add-OdbcDsn -Name $OdbcName -DriverName "ODBC Driver 13 for SQL Server" -DsnType 'System' -Platform '64-bit' -SetPropertyValue @("Server=$ServerName", "Trusted_Connection=Yes", "Database=$dbName") -ErrorAction SilentlyContinue -PassThru


##########################################################################
# Download test data sets 
##########################################################################

$env:Path +=";C:\Program Files\Microsoft SQL Server\MSSQL14.MSSQLSERVER\PYTHON_SERVICES"
$pyscript = $dataPath + "download_preprocess_data.py"
python $pyscript

Write-Host 
("Test data sets downloaded")

##########################################################################
# Deployment Pipeline
##########################################################################

$RStart = Get-Date
try
    {
    Write-Host 
    ("Import CSV File(s) for R Solution")
 
# upload csv files into SQL tables
        foreach ($dataFile in $dataList)
        {
            $destination = $dataPath + $dataFile 
            $tableName = $DBName + ".dbo." + $dataFile 
            $tableSchema = $dataPath + $dataFile + ".xml"
            bcp $tableName format nul -c -x -f $tableSchema -S $ServerName  -T
            bcp $tableName in $destination -S $ServerName -f $tableSchema -F 2 -C "RAW" -b 50000 -T
            Write-Host 
            ("Imported $destination")
        }
    }
catch
    {
    Write-Host -ForegroundColor DarkYellow 
    ("Exception in populating database tables:")
    Write-Host -ForegroundColor Red 
    ($Error[0].Exception)
throw
}
    Write-Host ("Finished loading data File(s).")

    Write-Host
    ("Training Model and Scoring Data in SQL with R scripts")

    $query = "EXEC Initial_Run_Once_R"
    Invoke-Sqlcmd -ServerInstance LocalHost -Database $dbName -Query $query -ConnectionTimeout  0 -QueryTimeout 0

    $Rend = Get-Date

    $Duration = New-TimeSpan -Start $RStart -End $Rend 
    
    Write-Host
    ("R Server Configured in $Duration")
}
ELSE 
    {Write-Host 
    ("There is not a R Version for this Solution so R will not be Installed")
    }

###Conifgure Database for Py 
if ($isCompatible -eq 'Yes'-and $InstallPy -eq 'Yes')
    {
    $PyStart = get-date
    Write-Host 
    ("Configuring $SolutionName Solution for Py")
    
    $dbname = $db + "_Py"

##########################################################################
# Deployment Pipeline Py
##########################################################################


    try {

        Write-Host 
        ("Import CSV File(s) for Python Solution")
        
        # upload csv files into SQL tables
            foreach ($dataFile in $dataList) 
            {
                $destination = $dataPath + $dataFile 
                $tableName = $DBName + ".dbo." + $dataFile 
                $tableSchema = $dataPath + $dataFile + ".xml"
                bcp $tableName format nul -c -x -f $tableSchema -S $ServerName  -T
                bcp $tableName in $destination -S $ServerName -f $tableSchema -F 2 -C "RAW" -b 50000 -T
                Write-Host 
                ("Imported $destination")
            }
        }
    catch 
        {
        Write-Host -ForegroundColor DarkYellow 
        ("Exception in populating database tables:")
        Write-Host -ForegroundColor Red 
        ($Error[0].Exception)
    throw
    }
    Write-Host 
    ("Finished loading .csv File(s)")

    Write-Host 
    ("Training Model and Scoring Data in SQL with Python scripts")
    $query = "EXEC Inital_Run_Once_Py"
    Invoke-Sqlcmd -ServerInstance LocalHost -Database $dbName -Query $query -ConnectionTimeout  0 -QueryTimeout 0

    $Pyend = Get-Date

    $Duration = New-TimeSpan -Start $PyStart -End $Pyend 
    Write-Host 
    ("Py Server Configured in $Duration")

}