######################################################################################################################################################
# Author: Paula Berenguel - Jul-17
# Description: 	This script will create a elastic pool and add databases to it
# How to run the script: & "C:\MyPS\add_elastic.ps1"
######################################################################################################################################################

# variables declaration
$resourcegroupname = "mls_rg"
$location = "East US"
$servername = "mls1dev"
$databasename = @("Northwind", "AdventureWorks2012", "ContosoRetailDW")
$elasticpoolname = "elasticmls1"


$elasticname =Get-AzureRmSqlElasticPool -ResourceGroupName $resourcegroupname -ServerName $servername
if ( -not $elasticname) { 
	Write-Output "Could not find Elastic Pool '$elasticpoolname' - will create it"
	Write-Output "Creating Elastic Pool '$elasticpoolname'"
	New-AzureRmSqlElasticPool -ResourceGroupName $resourcegroupname -ServerName $servername -ElasticPoolName $elasticpoolname -Edition "Basic" 
	
	For ($i=0; $i -lt $databasename.Length; $i++) {
		Set-AzureRmSqlDatabase -ResourceGroupName $resourcegroupname -DatabaseName $databasename[$i] -ServerName $servername -ElasticPoolName $elasticpoolname
	}
	}
else{
	Write-Output "Using existing Elastic Pool '$elasticpoolname'"
	}

