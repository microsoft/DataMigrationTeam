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

$dataFactory= `
    ( Get-AzureRmDataFactoryV2 -ResourceGroupName $resourceGroupName.ResourceGroupName | `
    Sort-Object -Property DataFactoryName |`
    Out-GridView `
        -Title "Select an Azure Data Factory ..." `
        -PassThru
    )


Set-AzureRmDataFactoryV2Pipeline `
    -DataFactoryName $DataFactory.DataFactoryName `
    -ResourceGroupName $resourceGroupName.ResourceGroupName `
    -Name "IterateAndCopyBlobToDW" `
    -DefinitionFile ".\02-adf\Pipelines\IterateAndCopyBlobToDW.json"

Set-AzureRmDataFactoryV2Pipeline `
    -DataFactoryName $DataFactory.DataFactoryName `
    -ResourceGroupName $resourceGroupName.ResourceGroupName `
    -Name "IterateAndCopyTDTablesToCSV" `
    -DefinitionFile ".\02-adf\Pipelines\IterateAndCopyTDTablesToCSV.json"

Set-AzureRmDataFactoryV2Pipeline `
    -DataFactoryName $DataFactory.DataFactoryName `
    -ResourceGroupName $resourceGroupName.ResourceGroupName `
    -Name "GetTableListAndTriggerCopyBlobtoSQLDW" `
    -DefinitionFile ".\02-adf\Pipelines\GetTableListAndTriggerCopyBlobtoSQLDW.json"

Set-AzureRmDataFactoryV2Pipeline `
    -DataFactoryName $DataFactory.DataFactoryName `
    -ResourceGroupName $resourceGroupName.ResourceGroupName `
    -Name "GetTableListAndTriggerCopyTDToCSV" `
    -DefinitionFile ".\02-adf\Pipelines\GetTableListAndTriggerCopyTDToCSV.json"


