# =================================================================================================================================================
# Scriptname: ScriptMPPObjectsDriver.ps1
# 
# Created: August, 2018
# Authors: Andy Isley and Gaiye "Gail" Zhou
# Company: Microsoft 
# 
# =================================================================================================================================================
# Description:
#       Driver to script out MPP objects to .dsql using PDWScripter
#
# ===============================================================================================================================================

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
#Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser
###############################################################################################
# User Input Here
###############################################################################################


$defaultConfigFilePath = "C:\APS2SQLDW\1_CreateMPPScripts"
$ConfigFilePath = Read-Host -prompt "Enter the directory where the Configuration CSV File resides or Press 'Enter' to accept the default [$($defaultConfigFilePath)]"
if($ConfigFilePath -eq "" -or $ConfigFilePath -eq $null)
	{$ConfigFilePath = $defaultConfigFilePath}

<# 
$defaultStatusLogPath = "C:\APS2SQLDW\Output\Log"
$StatusLogPath = Read-Host -prompt "Enter the name of the Output Log File Directory or press 'Enter' to the accept default: [$($defaultStatusLogPath)]"
	if($StatusLogPath -eq "" -or $StatusLogPath -eq $null)
		{$StatusLogPath = $defaultStatusLogPath}

$defaltStatusFileName = "1_CreateMppScripts_status.txt"
$StatusLog = Read-Host -prompt "Enter the name of the status file or press 'Enter' to accept the default: [$($defaltStatusFileName)]"
	if($StatusLog -eq "" -or $StatusLog -eq $null)
		{$StatusLog = $defaltStatusFileName}

if (!(test-path $StatusLogPath))
	{
		New-item "$StatusLogPath\" -ItemType Dir | Out-Null
	}

#>


$defaultPortNumber = "17001"
$PortNumber = Read-Host -prompt "Enter the APS port number or press 'Enter' to accept the default: [$($defaultPortNumber)]"
if($PortNumber -eq "" -or $PortNumber -eq $null)
{$PortNumber = $defaultPortNumber}


$UseIntegrated = Read-Host -prompt "Enter 'Yes' to connect using integrated Security. Enter 'No' otherwise."
	if($UseIntegrated -eq "" -or $UseIntegrated -eq $null)
	{$UseIntegrated = "No"}


if($UseIntegrated.ToUpper() -ne "YES")
	{
		$UserName = Read-Host -prompt "Enter the UserName to connect to the MPP System."
		if($UserName -eq "" -or $UserName -eq $null)
			{
				Write-Host "A password must be entered"
				 break
			}
		$Password = GetPassword
			if($Password -eq "") 
			{
				Write-Host "A password must be entered."
				break
			}
	}


$ScriptPath = Split-Path $MyInvocation.MyCommand.Path -Parent

. "$ScriptPath\ScriptObjectsTodSQL.ps1"  ##use this if using Powershell ver 2
#. "$PSCommandPath\RunSQLStatementExportCSV.ps1" ##use this if using Powershell ver 3+

foreach ($f in Get-ChildItem -path $ConfigFilePath  -Filter *.csv)
{
	Write-Host "File Name: " $f.Name.ToString()	

	$ObjectsToScriptDriverFile = $f.Name.ToString()	

	$csvFile = Import-Csv $ObjectsToScriptDriverFile #-ErrorVariable $ImportError -ErrorAction SilentlyContinue -

	ForEach ($ObjectToScript in $csvFile ) 
	{
		$Active = $ObjectToScript.Active
			if($Active -eq '1') 
		{
			$ServerName = $ObjectToScript.ServerName + "," + $PortNumber
			$DatabaseName = $ObjectToScript.DatabaseName
			$WorkMode = $ObjectToScript.WorkMode
			$OutputFolderPath = $ObjectToScript.OutputFolderPath
			$FileName = $ObjectToScript.FileName
			$Mode= $ObjectToScript.Mode
			$ObjectName = $ObjectToScript.ObjectName
			$ObjectToScript = $ObjectToScript.ObjectToScript
								
			if (!(test-path $OutputFolderPath))
			{
				New-item "$OutputFolderPath" -ItemType Dir | Out-Null
			}
	
			$OutpputFolderPathFileName = $OutputFolderPath + $FileName
			
			$test = $ObjectName.Split('.')
	
			if($ObjectName.Split('.').Length -eq 1)
			{
				$ObjectName = 'dbo.' + $ObjectName
			}
			elseif($ObjectName.Split('.')[0] -eq '')
			{
				$ObjectName = 'dbo' + $ObjectName
			}
			
			Write-Host Processing Export File: $ExportFileName 
			ScriptObjects $ServerName $UseIntegrated $UserName	$Password $DatabaseName $WorkMode $OutpputFolderPathFileName $Mode $ObjectName $ObjectToScript
			
		}
	}
	

}			 

