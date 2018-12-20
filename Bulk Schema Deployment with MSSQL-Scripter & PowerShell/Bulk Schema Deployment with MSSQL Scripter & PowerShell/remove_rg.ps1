##########################################################################
# Creator: Paula Berenguel - Jul/2017
# This PowerShell script will remove a resource group named mlsresource,
# How to run the script: & "C:\MyPS\remove_rg.ps1"
############################################################################

# ResourceGroup name
$resourcegroupname = "mls_rg"
Remove-AzureRmResourceGroup -ResourceGroupName $resourcegroupname