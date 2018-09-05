# FileName: RunSQLStatementExportCSV.ps1
# =================================================================================================================================================
# Scriptname: RunSQLStatementExportCSV
# 
# Change log:
# Created: July 13, 2017
# Author: Andy Isley
# Company: 
# 
# =================================================================================================================================================
# Description:
#       
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

function Run-Query($ServerName, 
				$UseIntegrated, 
				$UserName, 
				$Password, 
				$Query, 
				$FileName, 
				$CreateOutput, 
				$DatabaseName)
{
	if($UseIntegrated -eq 'Yes')
		{
			if($CreateOutput -eq '1')
			{
				$results = Invoke-Sqlcmd -Query $Query -QueryTimeout 3600 -ServerInstance "$ServerName" -Database $DatabaseName | Export-Csv -Path "$FileName" -append -Delimiter "," -NoTypeInformation
				return $results
			}
			else
			{
				$results = Invoke-Sqlcmd -Query $Query -QueryTimeout 3600 -ServerInstance "$ServerName" -Database $DatabaseName
				return $results
			}
		}
	else
		{
			if($CreateOutput -eq '1')
			{
				$results = Invoke-Sqlcmd -Query $Query  -QueryTimeout 3600 -ServerInstance "$ServerName" -Username $UserName -Password $Password -Database $DatabaseName | Export-Csv -Path "$FileName" -append -Delimiter "," -NoTypeInformation
				return $results
			}
			else
			{
				$results = Invoke-Sqlcmd -Query $Query  -QueryTimeout 3600 -ServerInstance "$ServerName" -Username $UserName -Password $Password -Database $DatabaseName
				return $results
			}
			
		}
}

function GetDbs($ServerName, 
				$UseIntegrated, 
				$UserName, 
				$Password,
				$Filename)
{
	
	$Query = "select name from sys.databases where name not in ('master','tempdb','stagedb', 'msdb', 'model', 'ReportServer$%') order by name desc;"
	#Write-host ServerName: $ServerName " " Query: $DBQuery

	$dbs = Run-Query $ServerName $UseIntegrated $UserName $Password $Query $Filename 0 'master'
	return $dbs
}

function Get-Tables($ServerName, 
				$UseIntegrated, 
				$UserName, 
				$Password, 
				$DBName, 
				$Filename)
{
		
	#$Query = "use [$DBName]; select t.name as name, s.name as SchemaName/*, t.is_external*/ from sys.tables t join sys.schemas as s on t.schema_id = s.schema_id order by t.name;"
	$Query = "use [$DBName]; Select t.name as name, s.name as SchemaName from sys.tables t join sys.schemas as s on t.schema_id = s.schema_id and t.object_id not in (select object_id from sys.external_tables) order by t.name;"
	#Write-host ServerName: $ServerName " " Query: $Query
	$tables = Run-Query $ServerName $UseIntegrated $UserName $Password $Query $Filename 0 $DBName
	return $tables
	
}

function Get-FileName($Filename, $PreAssessmentOutputPath)
{
	$FileCurrentTime = get-date -Format yyyyMMddHHmmss
	$ExportFilename = $PreAssessmentOutputPath + "\" + $Filename + "_" + "$FileCurrentTime.csv"
	Return $ExportFilename
}
function Get-FileNameByTable($Filename, $PreAssessmentOutputPath, $DBName, $SchemaName, $TableName)
{
	$FileCurrentTime = get-date -Format yyyyMMddHHmmss
	$ExportFilename = $PreAssessmentOutputPath + "\" + $Filename + "_" + $DBName + "_" + $SchemaName + "_" + $TableName + "_" + "$FileCurrentTime.csv"
	Return $ExportFilename
}

function RetrieveServerData($ServerName, 
							$UseIntegrated, 
							$UserName, 
							$Password, 
							$RunForEachDB, 
							$RunForEachTable, 
							$ExportFileName, 
							$SQLStatement, 
							$PreAssessmentOutputPath,
							$DBCCStatement)
{
	$Filename = Get-FileName $ExportFileName $PreAssessmentOutputPath

	if($RunForEachDB -eq '1')
		{
			$dbs = GetDBs $ServerName $UseIntegrated $UserName	$Password $Filename
			$databases = $dbs.name
			foreach($DBName in $databases)
			{
				Write-Host Processing Data for Database: $DBName
				if($RunForEachTable -eq '1')
				{
					$tables = Get-Tables $ServerName $UseIntegrated $UserName $Password $DBName $Filename
					#$dbTables = $tables.name
					foreach($Table in $tables)
					{
						Write-Host Processing Data for Database: $DBName and Table: $Table.Name Schema: $Table.SchemaName
						#Write-Host Query: $SQLStatement
						if($DBCCStatement -eq '1')
						{
							if($SQLStatement -eq 'PDW_ShowSpaceUsed')
							{
								$TableName = $Table.Name
								$SchemaName = $Table.SchemaName
								#$ExternalTable = $Table.Is_external
								#if ($ExternalTable -eq $false)
								#{
								$SQLStatement2 = "Use [$DBName]; DBCC PDW_SHOWSPACEUSED (""$SchemaName.$TableName"");"
								Write-Host Running DBCC statement for Database: $DBName and Table: $Table.Name Schema: $Table.SchemaName Query: $SQLStatement2
								#$Filename = Get-FileNameByTable $ExportFileName $PreAssessmentOutputPath $DBName $SchemaName $TableName
								$results = Run-Query $ServerName $UseIntegrated $UserName $Password $SQLStatement2 $Filename 0 $DBName
								$row_key = $DBName + '_' + $SchemaName + '_' + $TableName
								$data = @()
								foreach($result in $results)
								{
									$row = New-Object PSObject
									$row | Add-Member -MemberType NoteProperty -Name "DataBase" -Value $DBName -force
									$row | Add-Member -MemberType NoteProperty -Name "SchemaName" -Value $SchemaName -force
									$row | Add-Member -MemberType NoteProperty -Name "TableName" -Value $TableName -force
									$row | Add-Member -MemberType NoteProperty -Name "Rows" -Value $result.ROWS -force
									#Get KB size
									$Reserved_Space = $result.RESERVED_SPACE
									$DATA_SPACE = $result.DATA_SPACE
									$INDEX_SPACE = $result.INDEX_SPACE
									$UNUSED_SPACE = $result.UNUSED_SPACE
									$row | Add-Member -MemberType NoteProperty -Name "Reserved_Space_KB" -Value $RESERVED_SPACE -force
									$row | Add-Member -MemberType NoteProperty -Name "DATA_SPACEKB_KB"   -Value $DATA_SPACE -force
									$row | Add-Member -MemberType NoteProperty -Name "INDEX_SPACEKB_KB"  -Value $INDEX_SPACE -force
									$row | Add-Member -MemberType NoteProperty -Name "UNUSED_SPACEKB_KB"  -Value $UNUSED_SPACE -force
									#Get MB size 
									$Reserved_Space = $RESERVED_SPACE/1014
									$DATA_SPACE = $DATA_SPACE/1014
									$INDEX_SPACE = $INDEX_SPACE/1014
									$UNUSED_SPACE = $UNUSED_SPACE/1014
									$row | Add-Member -MemberType NoteProperty -Name "Reserved_Space_MB" -Value $RESERVED_SPACE -force
									$row | Add-Member -MemberType NoteProperty -Name "DATA_SPACE_MB"   -Value $DATA_SPACE -force
									$row | Add-Member -MemberType NoteProperty -Name "INDEX_SPACE_MB"  -Value $INDEX_SPACE -force
									$row | Add-Member -MemberType NoteProperty -Name "UNUSED_SPACE_MB"  -Value $UNUSED_SPACE -force
									#Get GB Size
									$Reserved_Space = $RESERVED_SPACE/1014
									$DATA_SPACE = $DATA_SPACE/1014
									$INDEX_SPACE = $INDEX_SPACE/1014
									$UNUSED_SPACE = $UNUSED_SPACE/1014
									$row | Add-Member -MemberType NoteProperty -Name "Reserved_Space_GB" -Value $RESERVED_SPACE -force
									$row | Add-Member -MemberType NoteProperty -Name "DATA_SPACE_GB"   -Value $DATA_SPACE -force
									$row | Add-Member -MemberType NoteProperty -Name "INDEX_SPACE_GB"  -Value $INDEX_SPACE -force
									$row | Add-Member -MemberType NoteProperty -Name "UNUSED_SPACE_GB"  -Value $UNUSED_SPACE -force
									#Get TB Size
									$Reserved_Space = $RESERVED_SPACE/1014
									$DATA_SPACE = $DATA_SPACE/1014
									$INDEX_SPACE = $INDEX_SPACE/1014
									$UNUSED_SPACE = $UNUSED_SPACE/1014
									$row | Add-Member -MemberType NoteProperty -Name "Reserved_Space_TB" -Value $RESERVED_SPACE -force
									$row | Add-Member -MemberType NoteProperty -Name "DATA_SPACE_TB"   -Value $DATA_SPACE -force
									$row | Add-Member -MemberType NoteProperty -Name "INDEX_SPACE_TB"  -Value $INDEX_SPACE -force
									$row | Add-Member -MemberType NoteProperty -Name "UNUSED_SPACE_TB"  -Value $UNUSED_SPACE -force

									$row | Add-Member -MemberType NoteProperty -Name "PDW_NODE_ID"  -Value $result.PDW_NODE_ID -force
									$row | Add-Member -MemberType NoteProperty -Name "DISTRIBUTION_ID"  -Value $result.DISTRIBUTION_ID -force
									$row | Add-Member -MemberType NoteProperty -Name "Row_key" -Value $row_key -force
									$data += $row 
								}
								$data | Export-Csv -Path "$FileName" -append -Delimiter "," -NoTypeInformation
								#}
							}
						}
						ELSE
						{
							$results = Run-Query $ServerName $UseIntegrated $UserName $Password $SQLStatement $Filename 1 $DBName
						}
					}
				}
				else
				{
					$results = Run-Query $ServerName $UseIntegrated $UserName $Password $SQLStatement $Filename 1 $DBName
				}
			}
		}
	else
	{
		$results = Run-Query $ServerName $UseIntegrated $UserName $Password $SQLStatement $Filename 1 'master'
		
	}
}