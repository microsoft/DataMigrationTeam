############################################################################################################
# Author: Paula Berenguel - Jul-17
# Description: This PowerShell script will create a resource group named mls_rg in EAST US location
# How to run the script: & "C:\MyPS\create_rg.ps1"
############################################################################################################


# variables declaration
$resourcegroupname = "mls_rg"
$location = "East US"


##creating the resource group called mls_rg in the location East US
$resourceGroup = Get-AzureRmResourceGroup -Name $resourcegroupname -Location $location -ErrorAction SilentlyContinue
if ( -not $ResourceGroup ) {
	Write-Output "Could not find resource group '$resourcegroupname' - will create it"
	Write-Output "Creating resource group '$resourcegroupname' in location '$location'"
	New-AzureRmResourceGroup -Name $resourcegroupname -Location $location
	}
else {  
	Write-Output "Resource group '$ResourceGroupName' already exists"
	}
	
	
## Validation:
## go to Azure and verify Resource Group was created succesfully or, simply run this script again.	


