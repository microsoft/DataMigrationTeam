#
# CreateSQLDWExtTableStatements.ps1
#
# FileName: CreateSQLDWExtTableStatements.ps1
# =================================================================================================================================================
# Scriptname: CreateSQLDWExtTableStatements.ps1
# 
# Change log:
# Created: April 2018
# Author: Andy Isley
# Company: 
# 
# =================================================================================================================================================
# Description:
#       Takes the Create Tables statement File and chagnes the With Clause to be a External Tables on SQLDW
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


function ScriptCreateExternalTableScript(
            $OutputFolderPath 
            ,$FileName 
            ,$InputFolderPath 
            ,$InputFileName 
            ,$SchemaName 
            ,$ObjectName 
            ,$DataSource 
            ,$FileFormat 
            ,$ExportLocation 
            ,$FileLocation)
{
# why creating input file path? 
	if (!(test-path $InputFolderPath))
	{
		New-item "$InputFolderPath" -ItemType Dir | Out-Null
    }

    if (!(test-path $OutputFolderPath))
	{
		New-item "$OutputFolderPath" -ItemType Dir | Out-Null
    }
    $OutputFolderPathFullName = $OutputFolderPath + $FileName + '.dsql'
    $InputFolderPathFileName = $InputFolderPath + $InputFileName 
        
    $SourceFile = Get-Content -path $InputFolderPathFileName

    $WithFound = $false

    foreach($l in $SourceFile)
    {
        if($l -match 'CREATE TABLE' -and !$WithFound)
        {

            $CreateClause = "CREATE EXTERNAL TABLE [" + $SchemaName + "].[" + $ObjectName + "]"
            if($l -match "[(]") 
                {$CreateClause = $CreateClause + "("}
            $CreateClause >> $OutputFolderPathFullName
        }
        elseif($l -match 'WITH \(' -and !$WithFound) 
        {
            $WithFound = $true
            $ExternalWith = " WITH (  
                LOCATION='" + $ExportLocation + "',  
                DATA_SOURCE = " + $DataSource + ",  
                FILE_FORMAT = " + $FileFormat + ")"

            $ExternalWith >> $OutputFolderPathFullName
        }
        elseif(!$WithFound)
        {
            $l >> $OutputFolderPathFullName
        }
    }
}