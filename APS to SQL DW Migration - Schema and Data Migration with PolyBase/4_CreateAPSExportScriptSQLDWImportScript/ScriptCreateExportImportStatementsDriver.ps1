#
# ScriptMPPObjects.ps1
#
# FileName: ScriptMPPObjectsDriver.ps1
# =================================================================================================================================================
# Scriptname: ScriptMPPObjectsDriver.ps1
# 
# Change log:
# Created: July, 2018
# Author: Andy Isley
# Company: 
# 
# =================================================================================================================================================
# Description:
#       Driver to script out MPP objects to .dsql using PDWScripter
#
# =================================================================================================================================================


# =================================================================================================================================================
# REVISION HISTORY
# =================================================================================================================================================
# Date: 
# Issue:  Initial Version
# Solution: 
# 
# =================================================================================================================================================

# =================================================================================================================================================
# FUNCTION LISTING
# =================================================================================================================================================
# Function:
# Created:
# Author:
# Arguments:
# =================================================================================================================================================
# Purpose:
#
# =================================================================================================================================================
#
# Notes: 
#
# =================================================================================================================================================
# SCRIPT BODY
# =================================================================================================================================================


function ScriptCreateExportObjects($DatabaseName
					,$OutputFolderPath 
					,$FileName
					,$SourceSchemaName 
					,$SourceObjectName 
					,$DestSchemaName 
					,$DestObjectaName 
					,$DataSource 
					,$FileFormat 
					,$ExportLocation)
					{

	if (!(test-path $OutputFolderPath))
	{
		New-item "$OutputFolderPath" -ItemType Dir | Out-Null
	}
	$OutpputFolderPathFileName = $OutputFolderPath + $FileName + '.dsql'

	$cmd = "Create External Table " + $DatabaseName + "." + $DestSchemaName + "." + $DestObjectaName + 
				"`r`nWITH (`r`n`tLOCATION='" + $ExportLocation + "',`r`n`tDATA_SOURCE = " + $DataSource + ",`r`n`tFILE_FORMAT = " + $FileFormat + "`r`n`t)`r`nAS `r`nSELECT * FROM " + $DatabaseName + "." + $SourceSchemaName +  "." + $SourceObjectName +
			"`r`n    Option(Label = 'Export_Table_" + $DatabaseName + "." + $SourceSchemaName +  "." + $SourceObjectName + "')"
		
	$cmd >> $OutpputFolderPathFileName 

}

function ScriptCreateImportObjects(
					$InsertFilePath 
					,$ImportSchema 
					,$SourceObjectName 
					,$DestSchemaName 
					,$DestObjectName 
					)

{
	if (!(test-path $InsertFilePath))
	{
		New-item "$InsertFilePath" -ItemType Dir | Out-Null
	}
	$InsertFilePathFull = $InsertFilePath + $FileName + '.dsql'

	$cmd = "INSERT INTO " + $ImportSchema + "." + $SourceObjectName + 
		"`r`n  SELECT * FROM " + $DestSchemaName +  "." + $DestObjectName +
		"`r`n`tOption(Label = 'Import_Table_" + $ImportSchema + "." + $SourceObjectName + "')"
		
	$cmd >> $InsertFilePathFull

}

function Display-ErrorMsg($ImportError, $ErrorMsg)
{
	#Write-Host $ImportError
	Write-Host $ImportError
}


$ScriptsDriverFile = Read-Host -prompt "Enter the name of the csv Driver File."
	if($ScriptsDriverFile -eq "" -or $ScriptsDriverFile -eq $null)
	{$ScriptsDriverFile = "C:\APS2SQLDW\4_CreateAPSExportScriptSQLDWImportScript\ScriptCreateExportImportStatementsDriver.csv"}
#$StatusLogPath = if((Read-Host -prompt "Enter the name of the Output File Directory.") -eq "") {"C:\Temp\APS_Scripts"}
#$StatusLog = if((Read-Host -prompt "Enter the name of the status file.") -eq "") {"status.txt"}

#Try{
$csvFile = Import-Csv $ScriptsDriverFile #-ErrorVariable $ImportError -ErrorAction SilentlyContinue -
#}
#Catch [System.IO.DirectoryNotFoundException]{
#	Display-ErrorMsg("Unable to import PreAssessment csv File: " + $APSPreAssessmentDriverFile)
#}

ForEach ($ObjectToScript in $csvFile ) 
{
	$Active = $ObjectToScript.Active
    if($Active -eq '1') 
	{

        $DatabaseName = $ObjectToScript.DatabaseName
		$OutputFolderPath = $ObjectToScript.OutputFolderPath
		$FileName = $ObjectToScript.FileName
		$SourceSchemaName= $ObjectToScript.SourceSchemaName
		$SourceObjectName= $ObjectToScript.SourceObjectName
		$DestSchemaName = $ObjectToScript.DestSchemaName
		$DestObjectaName = $ObjectToScript.DestObjectName
		$DataSource = $ObjectToScript.DataSource
		$FileFormat = $ObjectToScript.FileFormat
		$ExportLocation = $ObjectToScript.ExportLocation
		$InsertFilePath = $ObjectToScript.InsertFilePath
		$ImportSchema = $ObjectToScript.ImportSchema
				      
		
		#$OutpputFolderPathFileName = $OutputFolderPath + $FileName + '.dsql'
		#$ExportLocationFull = $ExportLocation
		
		#$securePassword = Read-Host "PDW Password" -AsSecureString
		
		Write-Host 'Processing Export Script for : '$SourceSchemaName'.'$SourceObjectName
		ScriptCreateExportObjects $DatabaseName $OutputFolderPath $FileName $SourceSchemaName $SourceObjectName $DestSchemaName $DestObjectaName $DataSource $FileFormat $ExportLocation
		
		ScriptCreateImportObjects $InsertFilePath $ImportSchema $SourceObjectName $DestSchemaName $DestObjectaName

	}
}