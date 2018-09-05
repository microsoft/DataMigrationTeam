############################################################################################################
############################################################################################################
# 
# Author: Gail Zhou
# August, 2018
# 
############################################################################################################
# Description:
#       Generate Configuration File for APS-to-SQLDW migration process 
# It takes input from the schema mapping file used in step 3, and output files produced in step 3 
#
############################################################################################################


# Get config file driver file name 
$defaultDriverFileName = "C:\APS2SQLDW\4_CreateAPSExportScriptSQLDWImportScript\ConfigFileDriver.csv"
$configFileDriverFileName = Read-Host -prompt "Enter the name of the config file driver file or press the 'Enter' key to accept the default [$($defaultDriverFileName)]"
if($configFileDriverFileName -eq "" -or $configFileDriverFileName -eq $null)
{$configFileDriverFileName = $defaultDriverFileName}


# Import CSV to get contents 
$configFileDriverFile = Import-Csv $configFileDriverFileName 
# The Config File Driver CSV file contains 'Name-Value' pairs. 
ForEach ($csvItem in $configFileDriverFile ) 
{
	$name = $csvItem.Name.Trim()
	$value = $csvItem.Value.Trim()

	if ($name -eq 'OneConfigFile') { $OneConfigFile = $value.ToUpper() } # YES or No 
	elseif ($name -eq 'OneConfigFileName') { $OneConfigFileName = $value } 
	elseif ($name -eq 'GeneratedConfigFileFolder') { $GeneratedConfigFileFolder = $value }
	elseif ($name -eq 'ExtTableShemaPrefix') { $ExtTableShemaPrefix = $value }
	elseif ($name -eq 'ExtTablePrefix') { $ExtTablePrefix = $value }
	elseif ($name -eq 'InputObjectsFolder')
	{
		$InputObjectsFolder = $value
		if (!(Test-Path -Path $InputObjectsFolder))
		{	
			Write-Output "Input File Folder " $InputObjectsFolder " does not exits."
			exit (0)
		}
	}
	elseif ($name -eq 'SchemaMappingFileFullPath')
	{
		$SchemaMappingFileFullPath = $value
		if (![System.IO.File]::Exists($SchemaMappingFileFullPath)) 
		{	
			Write-Output "Schema Mapping File " $SchemaMappingFileFullPath " does not exits."
			exit (0)
		}
	}
	elseif ($name -eq 'ApsExportScriptsFolder') { $ApsExportScriptsFolder = $value } 
	elseif ($name -eq 'SqldwImportScriptsFolder') { $SqldwImportScriptsFolder = $value }
	elseif ($name -eq 'ExternalDataSourceName') { $ExternalDataSourceName = $value }
	elseif ($name -eq 'FileFormat') { $FileFormat = $value }
	elseif ($name -eq 'ExportLocation') { $ExportLocation = $value }
	else {
		Write-Output "Encountered unknown configuration item: " + $name + " with Value: " + $value
	}

}

# Get Schema Mapping File into hashtable - same matrix in python file (step 3)
$smHT = @{}
$schemaMappingFile = Import-Csv $SchemaMappingFileFullPath
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
$inputObjectsFolderPath = Get-ChildItem -Path $InputObjectsFolder -Exclude *.dsql -Depth 1
$allDirNames = Split-Path -Path $inputObjectsFolderPath -Leaf
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

if ($OneConfigFile -eq "YES")
{
	$combinedOutputFile = $GeneratedConfigFileFolder + $OneConfigFileName 
	if (Test-Path $combinedOutputFile)
	{
		Remove-Item $combinedOutputFile -Force
	}
}

$inFilePaths = @{} 
$outFilePaths = @{} 
foreach ($dbName in $dbNames)
{
	$inFilePaths.Clear()
	$outFilePaths.Clear()

 	$dbFilePath = $InputObjectsFolder + $dbName + "\"
 
	# only need this folder to generate Export and Import Scripts 
	$inFilePaths.add("Tables",$dbFilePath + "Tables\")
	$outFilePaths.add("Tables",$GeneratedConfigFileFolder + "$dbName" + "_ExpImptStmtDriver_Generated.csv" )
	
	foreach ($key in $inFilePaths.Keys)
	{
		$inFileFolder = $inFilePaths[$key]
		$outCsvFileName = $outFilePaths[$key] 

		if (Test-Path $outCsvFileName)
		{
			Remove-Item $outCsvFileName -Force
		}

		foreach ($f in Get-ChildItem -path $inFileFolder  -Filter *dsql)
		{
			# exclude IDXS_ and STATS_ 
		 	if (($f.Name.ToString() -Match "IDXS_") -or ($f.Name.ToString() -Match "STATS_"))
		 	{
				 continue 
			}			 
			 
			$parts = @{}
			$parts.Clear()

			$firsLine = Get-Content -path $f.FullName -First 1
			
			if($firsLine -match "CREATE TABLE")
			{
			 $parts = getObjectNames $firsLine "CREATE TABLE"
			}
			elseif ($firsLine -match "CREATE PROC")
			{
				$parts = getObjectNames $firsLine "CREATE PROC"
			}
			elseif ($firsLine -match "CREATE VIEW")
			{
				$parts = getObjectNames $firsLine "CREATE VIEW"
			}
			else 
			{
				Write-Output "Unexpected first line here: " $firsLine
			}		
			 
		 	$sqldwSchema = $parts.Schema
		 	$objectName = $parts.Object
 
 
		 	$apsSchema = Get-ApsSchema $dbName $sqldwSchema $smHT

			$destSchema = -join($ExtTableShemaPrefix,$sqldwSchema) 
			$destObject = -join($ExtTablePrefix,$objectName)
			
		  $exportObjLocation = -join($ExportLocation,$dbName,"/",$apsSchema,"_",$objectName) # seperate scehame name and object name 
			$exportObjectFileName = -join($apsSchema,"_",$objectName) # seperate scehame name and object name 

			$apsExportScriptsFolderPerDb = -join($ApsExportScriptsFolder,$dbName,"\")

			$sqldwImportScriptsFolderPerDb = -join($SqldwImportScriptsFolder,$dbName,"\")
			

		 	$row = New-Object PSObject 		 
			$row | Add-Member -MemberType NoteProperty -Name "Active" -Value "1" -force
			$row | Add-Member -MemberType NoteProperty -Name "DatabaseName" -Value $dbName -force
			$row | Add-Member -MemberType NoteProperty -Name "OutputFolderPath" -Value $apsExportScriptsFolderPerDb -force
		 	$row | Add-Member -MemberType NoteProperty -Name "FileName" -Value $exportObjectFileName -force
		 	$row | Add-Member -MemberType NoteProperty -Name "SourceSchemaName" -Value $apsSchema -force
		 	$row | Add-Member -MemberType NoteProperty -Name "SourceObjectName" -Value $objectName -force	
		 	$row | Add-Member -MemberType NoteProperty -Name "DestSchemaName" -Value $destSchema -force
		 	$row | Add-Member -MemberType NoteProperty -Name "DestObjectName" -Value $destObject -force
		 	$row | Add-Member -MemberType NoteProperty -Name "DataSource" -Value $ExternalDataSourceName -force
			$row | Add-Member -MemberType NoteProperty -Name "FileFormat" -Value $FileFormat -force
		 	$row | Add-Member -MemberType NoteProperty -Name "ExportLocation" -Value $exportObjLocation -force
			$row | Add-Member -MemberType NoteProperty -Name "InsertFilePath" -Value $sqldwImportScriptsFolderPerDb -force
		 	$row | Add-Member -MemberType NoteProperty -Name "ImportSchema" -Value $sqldwSchema -force
		 	Export-Csv -InputObject $row -Path $outCsvFileName -NoTypeInformation -Append -Force 
			if ($OneConfigFile -eq "YES")
		 	{
				Export-Csv -InputObject $row -Path $combinedOutputFile -NoTypeInformation -Append -Force 
		 	}
		}
		if ([IO.File]::Exists($outCsvFileName)) 
		{
			Write-Output "          Completed writing to outCsvFileName: " $outCsvFileName
		}	 	
	} # end of each folder 
} # enf of foreach ($dbName in $dbNames)

if ( ($OneConfigFile -eq "YES") -and ([IO.File]::Exists($combinedOutputFile)) )
{
	Write-Output " ------------------------------------------------------------------------------------------------- "
	Write-Output "          Completed writing to outCsvFileName: " $combinedOutputFile
	Write-Output " ------------------------------------------------------------------------------------------------- "
}	 	
