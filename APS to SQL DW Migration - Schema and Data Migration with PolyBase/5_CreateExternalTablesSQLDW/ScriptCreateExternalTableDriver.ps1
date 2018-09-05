#
# ScriptMPPObjects.ps1
#
# FileName: ScriptCreateExternalTableDriver.ps1
# =================================================================================================================================================
# Scriptname: ScriptCreateExternalTableDriver.ps1
# 
# Change log:
# Created: July, 2018
# Author: Andy Isley
# Company: 
# 
# =================================================================================================================================================
# Description:
#       Generate "Create External Table" statements for SQLDW 
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


$ScriptsDriverFile = Read-Host -prompt "Enter the name of the Export csv Driver File."
	if($ScriptsDriverFile -eq "" -or $ScriptsDriverFile -eq $null)
	{$ScriptsDriverFile = "C:\APS2SQLDW\5_CreateExternalTablesSQLDW\ScriptCreateExternalTableDriver.csv"}
		#{$ScriptsDriverFile = "C:\Users\Charis\OneDrive - Microsoft\Powershell\CreateExternalTablesSQLDW\ScriptCreateExternalTableDriver_V1.csv"}



$ScriptPath = Split-Path $MyInvocation.MyCommand.Path -Parent
. "$ScriptPath\CreateSQLDWExtTableStatements.ps1"  

$csvFile = Import-Csv $ScriptsDriverFile

ForEach ($ObjectToScript in $csvFile ) 
{
	$Active = $ObjectToScript.Active
    if($Active -eq '1') 
	{

    #$DatabaseName = $ObjectToScript.DatabaseName
		$OutputFolderPath = $ObjectToScript.OutputFolderPath
		$FileName = $ObjectToScript.FileName
		$InputFolderPath= $ObjectToScript.InputFolderPath
		$InputFileName= $ObjectToScript.InputFileName
		$SchemaName = $ObjectToScript.SchemaName
		$ObjectName = $ObjectToScript.ObjectName
		$DataSource = $ObjectToScript.DataSource
		$FileFormat = $ObjectToScript.FileFormat
		$FileLocation = $ObjectToScript.FileLocation				      
		# Gail Zhou
		#Write-Host 'Processing Export Script for : '$SourceSchemaName'.'$SourceObjectName
		Write-Host 'Processing Export Script for : '$SchemaName'.'$ObjectName
		ScriptCreateExternalTableScript $OutputFolderPath $FileName $InputFolderPath $InputFileName $SchemaName $ObjectName $DataSource $FileFormat $FileLocation
		
	}
}