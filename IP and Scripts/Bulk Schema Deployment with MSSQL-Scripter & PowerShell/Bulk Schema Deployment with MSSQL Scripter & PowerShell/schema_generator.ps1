##########################################################################
# This PowerShell script will create a resource group named mlsresource,
# An Azure SQL Server named psserver1 and a list of Azure SQL Databases (psdb1 and psdb2)
# within psserver1 server - Basic Tier
# How to run the script? & "C:\MyPS\schema_generator.ps1"
############################################################################

$databasename = @("Northwind", "AdventureWorks2012", "ContosoRetailDW")

$File ="C:\MyPS\schema_run.ps1"
Clear-Content $File
#Get-Date + "#"| Out-File $File
For ($i=0; $i -lt $databasename.Length; $i++) {
	$dbscripter = "mssql-scripter -S MININT-H014C12 -d " + $databasename[$i] + " -U sa -P StarWars2017 --script-create --exclude-headers --check-for-existence -f C:\Python36-32\" + $databasename[$i] + ".sql --continue-on-error --target-server-version AzureDB --display-progress --exclude-use-database" | Out-File  $File -append
	}
	
& "C:\MyPS\schema_run.ps1"
