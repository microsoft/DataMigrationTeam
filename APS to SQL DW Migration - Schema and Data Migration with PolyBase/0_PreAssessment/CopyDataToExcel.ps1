# FileName: CopyDataToExcel.ps1 
# =================================================================================================================================================
# Scriptname: CopyDataToExcel.ps1 
# 
# Change log:
# Created: August, 2018
# Author: Andy Isley
# Company: 
# =================================================================================================================================================
#
# =================================================================================================================================================
# SCRIPT BODY
# =================================================================================================================================================

$defaultPreAssessmentOutputPath = "C:\APS2SQLDW\Output\0_PreAssessment"
$PreAssessmentOutputPath = Read-Host -prompt "Enter the Path to the Pre-Assessment output files or Press 'Enter' to accept default: [$($defaultPreAssessmentOutputPath)]"
    if($PreAssessmentOutputPath -eq "" -or $PreAssessmentOutputPath -eq $null) 
        {$PreAssessmentOutputPath = $defaultPreAssessmentOutputPath}

$ExcelFilePath = Read-Host -prompt "Enter the Path to save excel file or Press 'Enter' to accept default: [$($defaultPreAssessmentOutputPath)]"
    if($ExcelFilePath -eq "" -or $ExcelFilePath -eq $null) 
    {$ExcelFilePath = $defaultPreAssessmentOutputPath }


$defaultExcelFileName = "PreAssessment.xlsx"
$ExcelFileName = Read-Host -prompt "Enter the name of the excel file or Press 'Enter' to accept default: [$($defaultExcelFileName )]"
	if($ExcelFileName -eq "" -or $ExcelFileName -eq $null)
		{$ExcelFileName = $defaultExcelFileName}

$dir = $PreAssessmentOutputPath
$latest = Get-ChildItem -Path $dir -File 'ObjectCount*' | Sort-Object LastAccessTime -Descending | Select-Object -First 1
$ObjectCount_File = $latest.name

$latest = Get-ChildItem -Path $dir -File 'ShowSpaceUsed*' | Sort-Object LastAccessTime -Descending | Select-Object -First 1
$ShowSpaceUsed_File = $latest.name

$latest = Get-ChildItem -Path $dir -File 'TableMetaData*' | Sort-Object LastAccessTime -Descending | Select-Object -First 1
$TableMetadata_File = $latest.name

$latest = Get-ChildItem -Path $dir -File 'Version*' | Sort-Object LastAccessTime -Descending | Select-Object -First 1
$APSVersion_File = $latest.name

$latest = Get-ChildItem -Path $dir -File 'Distributions*' | Sort-Object LastAccessTime -Descending | Select-Object -First 1
$APSDistributions_File = $latest.name

if (!(test-path $ExcelFilePath))
	{
		New-item "$ExcelFilePath\" -ItemType Dir | Out-Null
    }

$PreAssessment_ExcelFile =  $ExcelFilePath + '\' + $ExcelFileName

If (Test-Path $PreAssessment_ExcelFile)
    {
        $DeleteFile = Read-Host -prompt "Would you like to delete the existing excel File(Y/N): $ExcelFileName?"
            if($DeleteFile.ToUpper() -eq "Y") 
                {Remove-Item $PreAssessment_ExcelFile -ErrorAction Ignore}
            else {break}
    }

$ShowSpaceUsed_File = $PreAssessmentOutputPath + '\' + $ShowSpaceUsed_File 
$ObjectCount_File = $PreAssessmentOutputPath + '\' + $ObjectCount_File
$TableMetadata_File = $PreAssessmentOutputPath + '\' + $TableMetadata_File
$APSVersion_File = $PreAssessmentOutputPath + '\' + $APSVersion_File
$APSDistributions_File = $PreAssessmentOutputPath + '\' + $APSDistributions_File

#Create the excel file
$excelFile = Export-Excel $PreAssessment_ExcelFile -PassThru

#Import ObjectCount to its own sheet
Write-host "Importing ObjectCount to its own sheet"
$csvFile = Import-Csv $ObjectCount_File
$excelFile = $csvFile | Export-Excel -ExcelPackage $excelFile -WorkSheetname 'ObjectCount' -TableStyle Medium16 -TableName 'ObjectCount' -ClearSheet -AutoSize -PassThru #-Show $false

#Import TableMetadata to its own sheet
Write-Host 'Importing TableMetadata to its own sheet'
$csvFile = Import-Csv $TableMetadata_File
$excelFile = $csvFile | Export-Excel -ExcelPackage $excelFile -WorkSheetname  'TableMetaData' -TableStyle Medium16 -TableName 'TableMetaData' -ClearSheet -AutoSize -PassThru #-Show

#Importing ShowSpaceUsed to its own sheet
Write-Host 'Importing ShowSpaceUsed to its own sheet'
$csvFile = Import-Csv $ShowSpaceUsed_File
$excelFile = $csvFile | Export-Excel -ExcelPackage $excelFile -WorkSheetname  'ShowSpaceUsed' -TableStyle Medium16 -TableName 'ShowSpaceUsed' -ClearSheet -AutoSize -PassThru  #-Show

#Importing Version to its own sheet
Write-Host 'Importing Version to its own sheet'
$csvFile = Import-Csv $APSVersion_File
$excelFile = $csvFile | Export-Excel -ExcelPackage $excelFile -WorkSheetname  'Version' -TableStyle Medium16 -TableName 'Version' -ClearSheet -PassThru -AutoSize

#Importing Distributions to its own sheet
Write-Host 'Importing Distributions to its own sheet'
$csvFile = Import-Csv $APSVersion_File
$excelFile = $csvFile | Export-Excel -ExcelPackage $excelFile -WorkSheetname  'Distributions' -TableStyle Medium16 -TableName 'Distributions' -ClearSheet -PassThru -AutoSize

$pt=[ordered]@{}

$pt.ObjectCntPvt=@{
    SourceWorkSheet='ObjectCount'
    PivotRows = "DBName"
    PivotData= @{'ObjectCount'='sum'}
    #IncludePivotChart=$false
    PivotColumns= 'type_desc'
    #Worksheetname= 'ObjectCountPivot'
}


$pt.TableSummaryPvt=@{
    SourceWorkSheet='TableMetaData'
    PivotRows = "IsPartitioned"
    PivotData= @{'TableName'='count'}
    PivotColumns= 'distribution_policy_desc'
    PivotFilter= 'DBName','SchemaName'
}

$pt.ShowSpaceSummaryPvt=@{
    SourceWorkSheet='ShowSpaceUsed'
    PivotRows = 'DataBase', 'SchemaName', 'TableName'
    #PivotColumns = 'Rows', 'Data_Space_MB', 'Data_Space_GB', 'Data_Space_TB'
    PivotData= @{'Rows'='Sum'}#;'Data_Space_MB'='Sum';'Data_Space_GB'='Sum';'Data_Space_TB'='Sum'}
}

Write-Host 'Building pivot tables'
$excelFile = Export-Excel -ExcelPackage $excelFile -PivotTableDefinition $pt -PassThru -Numberformat "#,##0.0"


$sheet1 = $excelFile.Workbook.Worksheets["ShowSpaceSummaryPvt"]
Set-Format -Address $sheet1.Cells["B:B"] -NumberFormat "#,##0.0"

$excelFile.Save()
$excelFile.Dispose()