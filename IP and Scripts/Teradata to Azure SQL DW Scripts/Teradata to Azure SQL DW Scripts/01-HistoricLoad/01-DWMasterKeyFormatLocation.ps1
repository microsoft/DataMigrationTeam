<#**************************************************************************************
The information contained in this document represents the current view of Microsoft Corporation on the issues discussed as of the date of
publication. Because Microsoft must respond to changing market conditions, this document should not be interpreted to be a commitment on the
part of Microsoft, and Microsoft cannot guarantee the accuracy of any information presented after the date of publication.

This document is for informational purposes only. MICROSOFT MAKES NO WARRANTIES, EXPRESS, IMPLIED, OR STATUTORY, AS TO THE INFORMATION IN THIS DOCUMENT.

Complying with all applicable copyright laws is the responsibility of the user. Without limiting the rights under copyright, no part of this
document may be reproduced, stored in or introduced into a retrieval system, or transmitted in any form or by any means (electronic, mechanical,
photocopying, recording, or otherwise), or for any purpose, without the express written permission of Microsoft Corporation.

Microsoft may have patents, patent applications, trademarks, copyrights, or other intellectual property rights covering subject matter in this
document. Except as expressly provided in any written license agreement from Microsoft, the furnishing of this document does not give you any
license to these patents, trademarks, copyrights, or other intellectual property.
*************************************************************************************#>

#Storage Variables
$storageAccountName = '<storageaccount>'
$ResourceGroup = '<resourcegroup>'
$ContainerName = '<blobcontainer>'
$location = '<location>'
$CredentialName = '<AzureSQLDWCredentialName>'
$ExternalDataSource = '<AzureSQLDWExternalDataSource>'

#SQL Variables
$ServerInstance = '<servername>.database.windows.net'
$DatabaseName = '<databasename>'
$LoginName = '<userid>'
$Password = '<password>'

#Connect to Azure
Connect-AzureRmAccount

<#
$storageAccount = New-AzureRmStorageAccount -ResourceGroupName $resourceGroup `
   -AccountName $storageAccountName `
    -Location $location -SkuName Standard_LRS -Kind BlobStorage -AccessTier Hot
#>
$storageAccount = Get-AzureRmStorageAccount -Name $storageAccountName -ResourceGroupName $ResourceGroup
$ctx = $storageAccount.Context

New-AzureStorageContainer -Name $containerName -Context $ctx -Permission blob -ErrorAction Continue

#use storage account key
#$accountSAS= New-AzureStorageAccountSASToken -Service Blob,File,Table,Queue -ResourceType Service,Container,Object -Permission "racwdlup" -Context $ctx
$SharedSecret=(Get-AzureRmStorageAccountKey -StorageAccountName $storageAccountName).Primary



#Master Key
$sqlQuery = @"
CREATE MASTER KEY;
"@

Invoke-SQLCmd -ServerInstance $ServerInstance `
    -Username $LoginName `
    -Password $Password `
    –Database $DatabaseName `
    –Query $sqlQuery

#Credential
$sqlQuery = @"
 CREATE DATABASE SCOPED CREDENTIAL $CredentialName
 WITH IDENTITY = 'SHARED ACCESS SIGNATURE',
 SECRET = '$sharedsecret';
"@

Invoke-SQLCmd -ServerInstance $ServerInstance `
    -Username $LoginName `
    -Password $Password `
    –Database $DatabaseName `
    –Query $sqlQuery

#Master Key
$sqlQuery = @"
CREATE EXTERNAL DATA SOURCE $ExternalDataSource 
    WITH (
        TYPE = HADOOP,
        LOCATION = 'wasbs://$ContainerName@$storageAccountName.blob.core.windows.net',
        CREDENTIAL = $CredentialName
    );
"@
$CredentialName
Invoke-SQLCmd -ServerInstance $ServerInstance `
    -Username $LoginName `
    -Password $Password `
    –Database $DatabaseName `
    –Query $sqlQuery


#File Format
$sqlQuery = @"
 CREATE EXTERNAL FILE FORMAT FastExportFormat 
 WITH 
 (FORMAT_TYPE = DELIMITEDTEXT,
    FORMAT_OPTIONS (FIELD_TERMINATOR = N'|', DATE_FORMAT = N'yyyy-MM-dd HH:mm:ss', USE_TYPE_DEFAULT = False))
"@

Invoke-SQLCmd -ServerInstance $ServerInstance `
    -Username $LoginName `
    -Password $Password `
    –Database $DatabaseName `
    –Query $sqlQuery