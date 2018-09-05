############################################################################################################
############################################################################################################
#
# Author: Gail Zhou
# August, 2018
# 
############################################################################################################
# Description:
#       Generate Configuration File for APS-to-SQLDW migration process 
# It takes input from the the scripts generated in step 4, and 5. 
#
############################################################################################################


# Get config file driver file name 
$defaultDriverFileName = "C:\APS2SQLDW\6_DeployScriptsToSqldw\ConfigFileDriver.csv"
$ConfigFileDriverFileName = Read-Host -prompt "Enter the name of the config file driver file or press the 'Enter' key to accept the default [$($defaultDriverFileName)]"
if($ConfigFileDriverFileName -eq "" -or $ConfigFileDriverFileName -eq $null)
{$ConfigFileDriverFileName = $defaultDriverFileName}


Write-Output (" Config Driver File: " + $ConfigFileDriverFileName)

# Import CSV to get contents 
$ConfigFileDriverFile = Import-Csv $ConfigFileDriverFileName 
# The Config File Driver CSV file contains 'Name-Value' pairs. 
ForEach ($csvItem in $ConfigFileDriverFile ) 
{
	$name = $csvItem.Name.Trim()
	$value = $csvItem.Value.Trim() 

	if ($name -eq 'OneConfigFileChoice') { $OneConfigFileChoice = $value.ToUpper() } # YES or No 
	elseif ($name -eq 'GeneratedConfigFileFolder') { $GeneratedConfigFileFolder = $value } 
	elseif ($name -eq 'OneApsExportConfigFileName') { $OneApsExportConfigFileName = $value } 
	elseif ($name -eq 'OneSqldwObjectsConfigFileName') { $OneSqldwObjectsConfigFileName = $value }
	elseif ($name -eq 'OneSqldwImportConfigFileName') { $OneSqldwImportConfigFileName = $value }
	elseif ($name -eq 'OneSqldwExtTablesConfigFileName') { $OneSqldwExtTablesConfigFileName = $value }
	elseif ($name -eq 'ActiveFlag') { $ActiveFlag = $value }
	elseif ($name -eq 'ApsServerName') { $ApsServerName = $value }
	elseif ($name -eq 'SqldwServerName') { $SqldwServerName = $value }  
	elseif ($name -eq 'SqldwDatabaseName') { $SqldwDatabaseName = $value }  
	elseif ($name -eq 'CreateSchemaFlag') { $CreateSchemaFlag = $value }  
	elseif ($name -eq 'SchemaAuth') { $SchemaAuth = $value }  
	elseif ($name -eq 'DropIfExistsFlag') { $DropIfExistsFlag = $value }  
	elseif ($name -eq 'Variables') { $Variables = $value }  
	elseif ($name -eq 'OutputObjectsFolder') { $OutputObjectsFolder = $value }  # there is really no objects to be produced in step 6
	elseif ($name -eq 'ApsExportScriptsFolder') 
	{ 
		$ApsExportScriptsFolder = $value 
		if (!(Test-Path -Path $ApsExportScriptsFolder))
		{	
			Write-Output "Input File Folder " $ApsExportScriptsFolder " does not exits."
			exit (0)
		}
	} 
	elseif ($name -eq 'SqldwImportScriptsFolder') 
	{ 
		$SqldwImportScriptsFolder = $value 
		if (!(Test-Path -Path $SqldwImportScriptsFolder))
		{	
			Write-Output "Input File Folder " $SqldwImportScriptsFolder " does not exits."
			exit (0)
		}
	}
	elseif ($name -eq 'SqldwExternalTablesFolder') 
	{ 
		$SqldwExternalTablesFolder = $value 
		if (!(Test-Path -Path $SqldwExternalTablesFolder))
		{	
			Write-Output "Input File Folder " $SqldwExternalTablesFolder " does not exits."
			exit (0)
		}
	}
	elseif ($name -eq 'SqldwObjectScriptsFolder') 
	{ 
		$SqldwObjectScriptsFolder = $value 
		if (!(Test-Path -Path $SqldwObjectScriptsFolder))
		{	
			Write-Output "Input File Folder " $SqldwObjectScriptsFolder " does not exits."
			exit (0)
		}
	}
	else {
		Write-Output "Encountered unknown configuration item: " + $name + " with Value: " + $value
	}
	Write-Output ("name: " + $name + " value: " + $value) 
}


# Get Schema Mapping File into hashtable - same matrix in python file (step 3)
$smHT = @{}
$schemaMappingFile = Import-Csv $schemaFileFullPath
$htCounter = 0 
foreach ($item in $schemaMappingFile)
{
	$htCounter++
	$smHT.add($htCounter,  @($item.ApsDbName, $item.ApsSchema, $item.SQLDWSchema))
}
# Get SQLDW Schema based on the schema mapping matrix 
function Get-TargetSchema($dbName, $apsSchema, $hT)
{
	foreach ($key in $hT.keys)
	{	
		$myValues = $hT[$key]
		if (($myValues[0] -eq $dbName) -and $myValues[1] -eq $apsSchema) 
		{
			return $myValues[2] 
		}
	}
}

function Get-ApsSchema($dbName, $sqldwSchema, $hT)
{
	foreach ($key in $hT.keys)
	{	
		$myValues = $hT[$key]
		if (($myValues[0] -eq $dbName) -and $myValues[2] -eq $sqldwSchema) 
		{
			return $myValues[1] 
		}
	}
}

Function getObjectNames ($line, $type)
{

  $line = $line.Replace('[','')
  $line = $line.Replace(']','')
  $lineLen = $line.Length
  
  $dbNameStart = ($type + " ").Length # example: $type = $Create External Table db.schema.table 
  $inputPart =  $line.Substring($dbNameStart, $lineLen-$dbNameStart) # the part without $type 

  $stringParts = @() 
  $partsCount = 0 # initialize 
  
  if ($inputPart -match " AS") 
  {
    $endingIndex = $inputPart.indexof(" ") # first space after meta data names 
    $metaDataString =  $inputPart.Substring(0,$endingIndex)
  
    $stringParts = $metaDataString.split(".")
    $partsCount = $stringParts.Count  
  }
  else {
    $stringParts = $line.Substring($dbNameStart, $lineLen-$dbNameStart).split(".")
    $partsCount = $stringParts.Count
  }
  
  $parts = @{}
  $parts.Clear()

  if ($partsCount -eq 1)
  {
    $parts.add("Object", $stringParts[0])  # object 
  } 
  elseif ($partsCount -eq 2)
  {
    $parts.add("Schema", $stringParts[0]) # schema
    $parts.add("Object", $stringParts[1]) # object
  }
  elseif ($partsCount -eq 3)
  {
    $parts.add("Database", $stringParts[0]) # db 
    $parts.add("Schema", $stringParts[1]) # schema
    $parts.add("Object", $stringParts[2]) # object 
  }
  else {
    Write-Output " Something is not right. Check this input line: " $line " and Type " $type 
  }
  return $parts 
}


# Get all the database names from directory names 
$subFolderPaths = Get-ChildItem -Path $SqldwObjectScriptsFolder -Exclude *.dsql -Depth 1
$allDirNames = Split-Path -Path $subFolderPaths -Leaf
$dbNames = New-Object 'System.Collections.Generic.List[System.Object]'
#get only dbNames 
foreach ($nm in $allDirNames)
{
	if ( (($nm.toUpper() -ne "Tables") -and ($nm.toUpper() -ne "Views") -and  ($nm.toUpper() -ne "SPs") )) { $dbNames.add($nm)} 
}
Write-Output " ---------------------------------------------- "
Write-Output "database names: " $dbNames 
Write-Output " ---------------------------------------------- "

################################################################################
#
# Key Section where each input folder and files are examined
#
################################################################################

# Set up one APS export config file & sqldw import config file
if ($OneConfigFileChoi -eq "YES")
{
	$oneApsExportConfigFileFullPath = $GeneratedConfigFileFolder + $OneApsExportConfigFileName 
	if (Test-Path $oneApsExportConfigFileFullPath)
	{
		Remove-Item $oneApsExportConfigFileFullPath -Force
	}
	$oneSqldwObjectsConfigFileNameFullPath = $GeneratedConfigFileFolder + $OneSqldwObjectsConfigFileName 
	if (Test-Path $oneSqldwObjectsConfigFileNameFullPath)
	{
		Remove-Item $oneSqldwObjectsConfigFileNameFullPath -Force
	}
	$OneSqldwImportConfigFileNameFullPath = $GeneratedConfigFileFolder + $OneSqldwImportConfigFileName 
	if (Test-Path $OneSqldwImportConfigFileNameFullPath)
	{
		Remove-Item $OneSqldwImportConfigFileNameFullPath -Force
	}
	$OneSqldwExtTablesConfigFileNameFullPath = $GeneratedConfigFileFolder + $OneSqldwExtTablesConfigFileName 
	if (Test-Path $OneSqldwExtTablesConfigFileNameFullPath)
	{
		Remove-Item $OneSqldwExtTablesConfigFileNameFullPath -Force
	}

}

# Step 6 To DO List
# (1) Create Tables/Views/SPs in SQLDW (take files from step 3) - 
# (2) Create APS external tables (Take files from step 4 export scripts)
# (3) Insert Stattement for SQLDW (Take files from step 4 insret statements - import sqldw) 
# (4) Create External Tables in SQLDW (take files from step 5)
# (5) Create Indexes and Stats (later...) check with Andy to see if the PS1 works with indexes and stats 

$inFilePaths = @{}
$outFilePaths = @{} 
$oneConfigFilePaths = @{}

$oneConfigFilePaths.add("OneConfigSqldwObjects",$GeneratedConfigFileFolder + $OneSqldwObjectsConfigFileName)
$oneConfigFilePaths.add("OneConfigSqldwExtTables",$GeneratedConfigFileFolder + $OneSqldwExtTablesConfigFileName)
$oneConfigFilePaths.add("OneConfigApsExport",$GeneratedConfigFileFolder + $OneApsExportConfigFileName)
$oneConfigFilePaths.add("OneConfigSqldwImport",$GeneratedConfigFileFolder + $OneSqldwImportConfigFileName)

foreach ($key in $oneConfigFilePaths.Keys)
{
	if (Test-Path $oneConfigFilePaths[$key])
	{
		Remove-Item $oneConfigFilePaths[$key] -Force
	}
}

foreach ($dbName in $dbNames)
{
	$inFilePaths.Clear()
	$outFilePaths.Clear()

	$dbFilePath = $SqldwObjectScriptsFolder + $dbName + "\"
	
	##################################################################
	# Input Files
	#################################################################
	
	
	# from Step 3
	$inFilePaths.add("SqldwTables",$dbFilePath + "Tables\")
	$inFilePaths.add("SqldwViews",$dbFilePath + "Views\" )
	$inFilePaths.add("SqldwSPs",$dbFilePath + "SPs\" )
	# from step 5
	$inFilePaths.add("SqldwExtTables",$SqldwExternalTablesFolder + $dbName + "\")

	# from step 4
	$inFilePaths.add("ApsExport",$ApsExportScriptsFolder + $dbName + "\")
	$inFilePaths.add("SqldwImport",$SqldwImportScriptsFolder + $dbName + "\")


	##################################################################
	# output Files
	#################################################################
	# For SQLDW 
	$outFilePaths.add("SqldwTables",$GeneratedConfigFileFolder + "$dbName" + "_Sqldw_Tables_Generated.csv" )
	$outFilePaths.add("SqldwViews",$GeneratedConfigFileFolder + "$dbName" + "_Sqldw_Views_Generated.csv" )
	$outFilePaths.add("SqldwSPs",$GeneratedConfigFileFolder + "$dbName" + "_Sqldw_SPs_Generated.csv" )
	$outFilePaths.add("SqldwExtTables",$GeneratedConfigFileFolder + "$dbName" + "_Sqldw_ExtTables_Generated.csv" )

	# for APS export and SQLDW Import 
	$outFilePaths.add("ApsExport",$GeneratedConfigFileFolder + "$dbName" + "_Aps_Export_Generated.csv"  )
	$outFilePaths.add("SqldwImport",$GeneratedConfigFileFolder + "$dbName" + "_Sqldw_Import_Generated.csv"  )

	
	foreach ($key in $inFilePaths.Keys)
	{
		$inFileFolder = $inFilePaths[$key]
		$outCsvFileName = $outFilePaths[$key] 
		if (Test-Path $outCsvFileName)
		{
			Remove-Item $outCsvFileName -Force
		}
		# test line: to remove later 
		#Write-Output ( " Key: " + $key + "  inFileFolder: " + $inFileFolder  + " outCsvFileName: " + $outCsvFileName )

		# Set Apart the required confi parameters based on key set earlier  
		if ($key -eq "SqldwTables") 
		{ 
			$objectType = "Table" 
			$serverName = $SqldwServerName
			$databaseName = $SqldwDatabaseName
	  }
		elseif ($key -eq "SqldwViews") 
		{ 
			$objectType = "View" 
			$serverName = $SqldwServerName
			$databaseName = $SqldwDatabaseName
	  } 
		elseif ($key -eq "SqldwSPs") 
		{ 
			$objectType = "SP" 
			$serverName = $SqldwServerName
			$databaseName = $SqldwDatabaseName
	  } 
		elseif ($key -eq "SqldwExtTables") 
		{ 
			$objectType = "EXT"
			$serverName = $SqldwServerName
			$databaseName = $SqldwDatabaseName
	  } 
		elseif ($key -eq "ApsExport") 
		{ 
			$objectType = "EXT" 
			$serverName = $ApsServerName
			$databaseName = $dbName
		} 
		# this is for Insert Into but we are not creating anything... need to check with Andy 
		# Two lines have internal and external objects/// 
		elseif ($key -eq "SqldwImport")  
		{ 
			#$objectType = "EXT"  #???? 
			$objectType = "Table"  #???? 
			$serverName = $SqldwServerName
			$databaseName = $SqldwDatabaseName
	  } 
		else 
		{
			Write-Output ("Unexpected Key for Object Type. Key received: " + $key) 
		}


		foreach ($f in Get-ChildItem -path $inFileFolder  -Filter *dsql)
		{
			$fileName = $f.Name.ToString()
			# exclude IDXS_ and STATS_ 
		 	if (($fileName -Match "IDXS_") -or ($fileName -Match "STATS_"))
		 	{
				 continue 
			}			 
			 
			$parts = @{}
			$parts.Clear() 

			$firsLine = Get-Content -path $f.FullName -First 1
			
			if($firsLine.ToUpper() -match "CREATE TABLE")
			{
			 $parts = getObjectNames $firsLine "CREATE TABLE"
			}
			elseif ($firsLine.ToUpper() -match "CREATE PROC")
			{
				$parts = getObjectNames $firsLine "CREATE PROC"
			}
			elseif ($firsLine.ToUpper() -match "CREATE VIEW")
			{
				$parts = getObjectNames $firsLine "CREATE VIEW"
			}
			elseif ($firsLine.ToUpper() -match "CREATE EXTERNAL TABLE")
			{
				$parts = getObjectNames $firsLine "CREATE EXTERNAL TABLE"
			}
			<# 
			# discuss this with Andy 
			INSERT INTO adw_dbo.DimDate
  		SELECT * FROM ext_adw_dbo.ext_DimDate
			Option(Label = 'Import_Table_adw_dbo.DimDate')
			#>
			elseif ($firsLine.ToUpper() -match "INSERT INTO")
			{
				$parts = getObjectNames $firsLine "INSERT INTO"
			}
			else 
			{
				Write-Output "Unexpected first line here: " $firsLine
			}		
			 
			$schemaName = $parts.Schema
		 	$objectName = $parts.Object

			$row = New-Object PSObject 		
			  
			$row | Add-Member -MemberType NoteProperty -Name "Active" -Value $ActiveFlag -force
			$row | Add-Member -MemberType NoteProperty -Name "ServerName" -Value $serverName -force
			$row | Add-Member -MemberType NoteProperty -Name "DatabaseName" -Value $databaseName  -force
			$row | Add-Member -MemberType NoteProperty -Name "FilePath" -Value $inFileFolder -force
			$row | Add-Member -MemberType NoteProperty -Name "CreateSchema" -Value $CreateSchemaFlag -force
			$row | Add-Member -MemberType NoteProperty -Name "ObjectType" -Value $objectType -force
			$row | Add-Member -MemberType NoteProperty -Name "SchemaAuth" -Value $SchemaAuth  -force
			$row | Add-Member -MemberType NoteProperty -Name "SchemaName" -Value $schemaName -force
			$row | Add-Member -MemberType NoteProperty -Name "ObjectName" -Value $objectName -force
			$row | Add-Member -MemberType NoteProperty -Name "DropIfExists" -Value $DropIfExistsFlag -force
			$row | Add-Member -MemberType NoteProperty -Name "Variables" -Value $Variables -force
			$row | Add-Member -MemberType NoteProperty -Name "FileName" -Value 	$fileName  -force
			Export-Csv -InputObject $row -Path $outCsvFileName -NoTypeInformation -Append -Force 
			 
			if ($oneConfigFile -eq "YES")
		 	{
				if ( ($key -eq "SqldwTables") -or ($key -eq "SqldwViews") -or ($key -eq "SqldwSPs") )
				{
					Export-Csv -InputObject $row -Path  $oneConfigFilePaths.OneConfigSqldwObjects -NoTypeInformation -Append -Force 		 
				}
				elseif ( ($key -eq "SqldwExtTables") )
				{
					Export-Csv -InputObject $row -Path  $oneConfigFilePaths.OneConfigSqldwExtTables -NoTypeInformation -Append -Force 
				}			
				elseif ( ($key -eq "ApsExport"))
				{
					Export-Csv -InputObject $row -Path  $oneConfigFilePaths.OneConfigApsExport -NoTypeInformation -Append -Force 
				}
				elseif ( ($key -eq "SqldwImport"))
				{
					Export-Csv -InputObject $row -Path  $oneConfigFilePaths.OneConfigSqldwImport -NoTypeInformation -Append -Force 
				}
				else 
				{
					Write-Output ("Error: please look at key " + $key )
				}					
			}
		}
		if ([IO.File]::Exists($outCsvFileName)) 
		{
			Write-Output "**************************************************************************************************************"
			Write-Output ("   Completed writing to outCsvFileName: " + $outCsvFileName)
			Write-Output " "
		}	 
	} # end of each folder 
} # enf of foreach ($dbName in $dbNames)



foreach ($key in $oneConfigFilePaths.Keys)
{
	if ([IO.File]::Exists($oneConfigFilePaths[$key])) 
	{
		Write-Output " -------------------------------------------------------------------------------------------------------------------- "
		Write-Output ("        Completed writing to combined config File: " + $oneConfigFilePaths[$key] )
		Write-Output " "
	}	 	
}

$finishTime = Get-Date
Write-Output ("          Finished at: " + $finishTime)
Write-Output " "
