##########################################################################
# This PowerShell script will deploy an schema to a Azure SQL db
# How to run the script? & "C:\MyPS\schema_deploy.ps1"
############################################################################



# The data center and resource group name
$resourcegroupname = "mls_rg"
$location = "East US"

# The logical server name: Use a random value or replace with your own value (do not capitalize)
$servername = "mls1dev"
$adminlogin = "corp"
$password = "NorthStar2015"

# The ip address range that you want to allow to access your server - change as appropriate
$startip = "0.0.0.0"
$endip = "0.0.0.0"

# List of databases
$databasename = @("Northwind", "AdventureWorks2012", "ContosoRetailDW")

$DBDataPath = "C:\Python36-32\"
$DBLogPath = "C:\Python36-32\"


$DBScriptFile=''
$DBLogPathFile=''
For ($i=0; $i -lt $databasename.Length; $i++) {
$azuresqldb= Get-AzureRmSqlDatabase -ResourceGroupName $resourcegroupname -ServerName $servername -DatabaseName $databasename[$i] -ErrorAction SilentlyContinue
if ( -not $azuresqldb ) { #checking for database existence
		"Could not find Azure SQL Database " + $databasename[$i]
	}
	else{
		$DBScriptFile = $DBDataPath + $databasename[$i] + '.sql'
		$DBLogPathFile = $DBLogPath + $databasename[$i] + '_log.txt'
		sqlcmd -U corp -S mls1dev.database.windows.net -P $password -d $databasename[$i] -j -i $DBScriptFile  -o $DBLogPathFile
		"Azure SQL Database " + $databasename[$i] + " deployed"

	}
}

