############################################################################################################
# Author: Paula Berenguel - Jul-17
# Description: This PowerShell script will create an Azure SQL Server named mls1dev
# How to run the script: & "C:\MyPS\create_sqlserver.ps1"
############################################################################################################


# variables declaration
$resourcegroupname = "mls_rg"
$location = "East US"

# do not capitalize
$servername = "mls1dev"
$adminlogin = "corp"
$password = "NorthStar2015"

# The ip address range that you want to allow to access your server - change as appropriate
$startip = "0.0.0.0"
$endip = "0.0.0.0"

# List of databases
$databasename = @("Northwind", "AdventureWorks2012", "ContosoRetailDW")


$sqlservername =Get-AzureRmSqlServer -ResourceGroupName $resourcegroupname -ServerName $servername -ErrorAction SilentlyContinue
if ( -not $sqlservername) { 
	Write-Output "Could not find Azure SQL Server '$servername' - will create it"
	Write-Output "Creating Azure SQL Server '$servername', resource group '$resourcegroupname' in location '$location'"
	New-AzureRmSqlServer -ResourceGroupName $resourcegroupname -ServerName $servername -Location $location   -SqlAdministratorCredentials $(New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $adminlogin, $(ConvertTo-SecureString -String $password -AsPlainText -Force))
	Write-Output "Setting up Firewall Rule"
	New-AzureRmSqlServerFirewallRule -ResourceGroupName $resourcegroupname   -ServerName $servername   -FirewallRuleName "AllowSome" -StartIpAddress $startip -EndIpAddress $endip
	}
else{
	Write-Output "Azure SQL Server '$servername' already exists"
	}
	
	
## Validation:
## go to Azure and verify SQL Server was created succesfully or, simply run this script again.	