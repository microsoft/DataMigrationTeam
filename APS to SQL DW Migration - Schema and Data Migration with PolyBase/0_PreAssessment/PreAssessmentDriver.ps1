# FileName: PreAssessmentDriver.ps1
# =================================================================================================================================================
# Scriptname: PreAssessmentDriver.ps1
# 
# Change log:
# Created: August, 2018
# Author: Andy Isley
# Company: 
# 
# =================================================================================================================================================
# Description:
#       Driver to BCP files out of SQL for the purpose to gather info to complete an Assessment for migrating APS to another Platform
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

function Display-ErrorMsg($ImportError, $ErrorMsg)
{
	Write-Host $ImportError
}
Function GetPassword($securePassword)
{
       $securePassword = Read-Host "PDW Password" -AsSecureString
       $P = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))
       return $P
}

$defaultPreAssessmentDriverFile = "C:\APS2SQLDW\0_PreAssessment\SQLScriptstoRun.csv"
$PreAssessmentDriverFile = Read-Host -prompt "Enter the name of the ScriptToRun csv File or Press 'Enter' to accept default [$($defaultPreAssessmentDriverFile)]"
	if($PreAssessmentDriverFile -eq "" -or $PreAssessmentDriverFile -eq $null)
		{$PreAssessmentDriverFile = $defaultPreAssessmentDriverFile}

$defaultPreAssessmentOutputPath = "C:\APS2SQLDW\Output\0_PreAssessment"
$PreAssessmentOutputPath = Read-Host -prompt "Enter the name of the Output File Directory or Press 'Enter' to accept default [$($defaultPreAssessmentOutputPath)]"
	if($PreAssessmentOutputPath -eq "" -or $PreAssessmentOutputPath -eq $null)
	{$PreAssessmentOutputPath = $defaultPreAssessmentOutputPath}

# Note: When we publish this code, the IP address needs to be deleted.
$msftApsServerName = "10.209.220.105,17001" # sqlservercharis.database.windows.net#10.209.220.105,17001
$ServerName = Read-Host -prompt "Enter the name of the Server ('APS Server Name or IP Address, 17001')"
	if($ServerName -eq "" -or $ServerName -eq $null) 
		{$ServerName = $msftApsServerName} 

$UseIntegrated = Read-Host -prompt "Enter the 'Yes' to connect using integrated Security, otherwise Enter 'No' "
$UseIntegrated = $UseIntegrated.ToUpper()
If($UseIntegrated.ToUpper() -eq "NO")
{
	$UserName = Read-Host -prompt "Enter the UserName if not using Integrated."
		if($UserName -eq "" -or $UserName -eq $null) {$UserName = "sa"}
	$Password = GetPassword
		if($Password -eq "") {Write-Host "A password must be entered"
							break}
}

$ScriptPath = Split-Path $MyInvocation.MyCommand.Path -Parent

. "$ScriptPath\RunSQLStatementExportCSV.ps1"

if (!(test-path $PreAssessmentOutputPath))
	{
		New-item "$PreAssessmentOutputPath\" -ItemType Dir | Out-Null
	}


$csvFile = Import-Csv $PreAssessmentDriverFile


ForEach ($ScriptToRun in $csvFile ) 
{
	$Active = $ScriptToRun.Active
    if($Active -eq '1') 
	{
    $RunForEachDB = $ScriptToRun.RunForEachDB
		$RunForEachTable = $ScriptToRun.RunForEachTable
		$ExportFileName = $ScriptToRun.ExportFileName
		$SQLStatement = $ScriptToRun.SQLStatement
		$DBCCStatement = $ScriptToRun.DBCCStatement
        
		Write-Host Processing Export File: $ExportFileName 
		RetrieveServerData $ServerName $UseIntegrated $UserName	$Password $RunForEachDB $RunForEachTable $ExportFileName $SQLStatement $PreAssessmentOutputPath $DBCCStatement
	}
}
