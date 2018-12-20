######################################################################################################################################################
# Author: Paula Berenguel - Jul-17
# Description: 	This script will create one or more of empty databases in the server named mls1dev. 
#				The list of databases should be specified in the $databasename variable
#	    		Databases will be creating in Standard S3 tier	
#				RequestedServiceObjectiveName possible values include: 'Basic', 'S0', 'S1', 'S2', 'S3', 'P1', 'P2', 'P3', 'P4', 'P6', 'P11', 'P15'		
# How to run the script: & "C:\MyPS\create_sqldb.ps1"
######################################################################################################################################################

# variables declaration
$resourcegroupname = "mls_rg"	#resourcegroup
$location = "East US"			#location


$servername = "mls1dev"   	#servername
$startip = "0.0.0.0"		#startIP address for creating Firewall rules to azure services
$endip = "0.0.0.0"			#endip address for creating Firewall rules to azure services


$databasename = @("Northwind", "AdventureWorks2012", "ContosoRetailDW")   # List of databases - 

## database creation
For ($i=0; $i -lt $databasename.Length; $i++) {
	$azuresqldb= Get-AzureRmSqlDatabase -ResourceGroupName $resourcegroupname -ServerName $servername -DatabaseName $databasename[$i] -ErrorAction SilentlyContinue
	if ( -not $azuresqldb ) {
		"Creating Azure SQL Database " + $databasename[$i]  + " in Server Name '$servername'"
		# Standard Tier.
		New-AzureRmSqlDatabase  -ResourceGroupName $resourcegroupname -ServerName $servername -DatabaseName $databasename[$i]  -RequestedServiceObjectiveName "S3"
	}
	else{
		"Azure SQL Database already exists " + $databasename[$i] 
	}

}