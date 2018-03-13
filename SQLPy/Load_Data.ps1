<#
.SYNOPSIS
Script to load the Newsgroup data into SQL Server.
#>

[CmdletBinding()]
param(

[parameter(Mandatory=$true,ParameterSetName = "P")]
[ValidateNotNullOrEmpty()] 
[String]    
$ServerName = "",

[parameter(Mandatory=$true,ParameterSetName = "P")]
[ValidateNotNullOrEmpty()]
[String]
$DBName = "",

[parameter(Mandatory=$true,ParameterSetName = "P")]
[ValidateNotNullOrEmpty()]
[String]
$username ="",


[parameter(Mandatory=$true,ParameterSetName = "P")]
[ValidateNotNullOrEmpty()]
[String]
$password ="",

[parameter(Mandatory=$false,ParameterSetName = "P")]
[ValidateNotNullOrEmpty()]
[String]
$dataPath = ""
)

$scriptPath = Get-Location
$filePath = $scriptPath.Path+ "\"
$error = $scriptPath.Path + "\output.log"


if ($dataPath -eq "")
{
$parentPath = Split-Path -parent $scriptPath
$dataPath = $parentPath + "\Data\"
}


##########################################################################
# Function wrapper to invoke SQL command
##########################################################################
function ExecuteSQL
{
param(
[String]
$sqlscript
)
    Invoke-Sqlcmd -ServerInstance $ServerName  -Database $DBName -Username $username -Password $password -InputFile $sqlscript -QueryTimeout 200000
}

##########################################################################
# Function wrapper to invoke SQL query
##########################################################################
function ExecuteSQLQuery
{
param(
[String]
$sqlquery
)
    Invoke-Sqlcmd -ServerInstance $ServerName  -Database $DBName -Username $username -Password $password -Query $sqlquery -QueryTimeout 200000
}

##########################################################################
# Check if the SQL server or database exists
##########################################################################
$query = "IF NOT EXISTS(SELECT * FROM sys.databases WHERE NAME = '$DBName') CREATE DATABASE $DBName"
Invoke-Sqlcmd -ServerInstance $ServerName -Username $username -Password $password -Query $query -ErrorAction SilentlyContinue
if ($? -eq $false)
{
    Write-Host -ForegroundColor Red "Failed the test to connect to SQL server: $ServerName database: $DBName !"
    Write-Host -ForegroundColor Red "Please make sure: `n`t 1. SQL Server: $ServerName exists;
                                     `n`t 2. SQL database: $DBName exists;
                                     `n`t 3. SQL user: $username has the right credential for SQL server access."
    exit
}

$query = "USE $DBName;"
Invoke-Sqlcmd -ServerInstance $ServerName -Username $username -Password $password -Query $query 


##########################################################################
# Download the data. 
##########################################################################
$env:Path +=";C:\Program Files\Microsoft SQL Server\MSSQL14.MSSQLSERVER\PYTHON_SERVICES"
$pyscript = $dataPath + "download_preprocess_data.py"
python $pyscript


##########################################################################
# Load the data
##########################################################################
$startTime= Get-Date
Write-Host "Start time is:" $startTime
try{

        # Create raw table.
        Write-Host -ForeGroundColor 'green' ("Inserting raw data into SQL Fraud table...")
        $script = $filePath + "step0_create_tables.sql"
        ExecuteSQL $script
    
        $dataList = "News_Train", "News_Test", "Label_Names"
		
		# Upload tsv files into SQL table.
        foreach ($dataFile in $dataList)
        {
            $destination = $dataPath + $dataFile 
            $tableName = $DBName + ".dbo." + $dataFile 
            $tableSchema = $dataPath + $dataFile + ".xml"
            bcp $tableName format nul -c -x -f $tableSchema  -U $username -S $ServerName -P $password  
            bcp $tableName in $destination -S $ServerName -f $tableSchema -F 2 -C "RAW" -b 50000 -U $username -P $password 
        }
    }
    catch
    {
        Write-Host -ForegroundColor DarkYellow "Exception in populating database tables:"
        Write-Host -ForegroundColor Red $Error[0].Exception 
        throw
    }
    
$endTime =Get-Date
$totalTime = ($endTime-$startTime).ToString()
Write-Host "Finished running at:" $endTime
Write-Host "Total time used: " -foregroundcolor 'green' $totalTime.ToString()

