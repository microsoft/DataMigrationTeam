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
#ADFTutorialIR

$resourceGroupName = `
    ( Get-AzureRmResourceGroup | `
    Sort-Object -Property ResourceGroupName |`
    Out-GridView `
        -Title "Select an Azure Resource Group ..." `
        -PassThru
    )

$dataFactoryName= `
    ( Get-AzureRmDataFactoryV2 -ResourceGroupName $resourceGroupName.ResourceGroupName | `
    Sort-Object -Property DataFactoryName |`
    Out-GridView `
        -Title "Select an Azure Data Factory ..." `
        -PassThru
    )



$SelfintegrationRuntimeName= `
(Get-AzureRmDataFactoryV2IntegrationRuntime `
-ResourceGroupName $resourceGroupName.ResourceGroupName `
-DataFactoryName $dataFactoryName.DataFactoryName | `
Sort-Object -Property DataFactoryName |`
    Out-GridView `
        -Title "Select an SELF HOSTED Integration Runtime ..." `
        -PassThru
)


#Self Hosted IR
#Teradata
New-AzureRmDataFactoryV2LinkedServiceEncryptedCredential `
    -DataFactoryName $dataFactoryName.DataFactoryName `
    -ResourceGroupName $ResourceGroupName.ResourceGroupName `
    -IntegrationRuntimeName $SelfintegrationRuntimeName.Name `
    -File ".\02-adf\Connectors\TeradataLinkedService.json" > $ScriptDir\Connectors\encryptedTeradataLinkedService.json `
    -Force

Set-AzureRmDataFactoryV2LinkedService `
    -DataFactoryName $dataFactoryName.DataFactoryName `
    -ResourceGroupName $ResourceGroupName.ResourceGroupName `
    -Name "EncryptedTeradataLinkedService" `
    -File ".\02-adf\Connectors\encryptedTeradataLinkedService.json"

#File Share
New-AzureRmDataFactoryV2LinkedServiceEncryptedCredential `
    -DataFactoryName $dataFactoryName.DataFactoryName `
    -ResourceGroupName $ResourceGroupName.ResourceGroupName `
    -IntegrationRuntimeName $SelfintegrationRuntimeName.Name `
    -File ".\02-adf\Connectors\FileLinkedService.json" > $ScriptDir\02-adf\Connectors\encryptedFileLinkedService.json `
    -Force

Set-AzureRmDataFactoryV2LinkedService `
    -DataFactoryName $dataFactoryName.DataFactoryName `
    -ResourceGroupName $ResourceGroupName.ResourceGroupName `
    -Name "EncryptedFileLinkedService" `
    -File ".\02-adf\Connectors\encryptedFileLinkedService.json"

#Dedicated IR
#Blob Storage
Set-AzureRmDataFactoryV2LinkedService `
-DataFactoryName $dataFactoryName.DataFactoryName `
-ResourceGroupName $ResourceGroupName.ResourceGroupName `
-Name "AzureStorageLinkedService" `
-File ".\02-adf\Connectors\AzureStorageLinkedService.json"

#Azure SQL DW
Set-AzureRmDataFactoryV2LinkedService `
-DataFactoryName $dataFactoryName.DataFactoryName `
-ResourceGroupName $resourceGroupName.ResourceGroupName `
-Name "AzureSqlDWLinkedService" `
-File ".\02-adf\Connectors\AzureSqlDWLinkedService.json"
