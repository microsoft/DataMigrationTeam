#
# ConvertNetezza_to_SQLDW.ps1
#

$NetezzaFileName = "cr8tbls4poc.sql"

$NetezzaPath = "C:\Users\charis\Documents\Clients\Carolina Health\Client Files\"
$ADWPath = "C:\Users\charis\Documents\Clients\Carolina Health\Client Files\ADWScripts\"

#Query Labels and Audit Table Desctiption.
$DWUsetting = 'DWU 2000'
$LoadTableComment = "Initial Load Test"

#Polybase configuration
$PolybaseDatasource = "uds_wasb_CHS_POC_ConvertedData"
$PolybaseFileFormat = "uff_CHS_POC_A_delimited"
$PloybaseFileLocation = ""
$RejectType = 'Value'
$RejectValue = 10000

#Turn on and Off Features of the DDL conversion
$CreateExternal = $true #Should the External Table be created
$CreateTable = $false #Should the conversion create a test table without having to run a CTAS.  This is helpful for creating all objects to test reports/SQL while the load is happening
$CreateIndex = $true #Should an index be created
$CreateCTAS = $true #Create the CTAS statement
$CreateValidateData = $true #Create a test query to return the total number of rows loaded.  This is not necessary when loading the data and can be removed.

#for debugging
$StopTableName = "DM_ORG_UNIT_DIV"

$ADWTableFileName = ""
$FileOpen = $false

#Set source file path and file name
$src = [System.IO.Path]::Combine($NetezzaPath,$NetezzaFileName )

#Set target file path and file name
#$tgt = [System.IO.Path]::Combine($ADWPath,$ADWFileName )

$read = New-Object System.IO.StreamReader($src)


$FirstTable = 0;
$ColumnList = New-Object System.Collections.Generic.List[System.Object]
$EmptyColumnList = New-Object System.Collections.Generic.List[System.Object]



while ($read.Peek() -ne -1)
{
	$line =  $read.ReadLine();
	If ($line -match "CREATE TABLE")
	{
		#$write.WriteLine($line);
		
		
		$LastIdx = $line.LastIndexOf(" ");
		$TableName = $line.Substring($LastIdx + 1, $line.Length - $LastIdx-1)

		#Set target file path and file name
		$ADWTableFileName = 'Load_' + $TableName + '.sql'
		$tgt = [System.IO.Path]::Combine($ADWPath,$ADWTableFileName)
		$write = New-Object System.IO.StreamWriter($tgt,$append)
		$FileOpen = $true

		if($TableName -eq $StopTableName)
		{
			Write-Host $TableName
		}
		if($CreateExternal)
		{
		$write.WriteLine("--- CREATE EXTERNAL DW TABLE ---");
		$write.WriteLine("");
		$IfExist = "if Exists(select 1 from sys.tables where name = 'Ext_$TableName') Drop External Table [dbo].[Ext_$TableName]"
		$write.WriteLine($IfExist);
		$Line =  "CREATE EXTERNAL TABLE Ext_$TableName";
		
		}
		$ColumnList.Clear();

		while($read -ne -1)
		{
			if($line -match "DISTRIBUTE")
			{
				if($line -match "RANDOM")
				{
					Write-Host "$TableName is distributed Round_Robin"
					$Round_Robin = $true
				}
				else
				{
				$position = $line.IndexOf("(") + 1;
				$Lastposition = $line.IndexOf(")");
				$length = $line.Length;
				$distColumnLength = $length - $position - 1;
				$DistColumn = $line.Substring($position, $distColumnLength);
				if ($DistColumn -match ",")
					{
						Write-Host "$TableName is distributed on multiple columns: $DistColumn"
						$CommaPosition = $DistColumn.IndexOf(",");
						$DistColumn = $DistColumn.Substring(0, $CommaPosition);

					}
				$Round_Robin = $false
				}
				if($CreateExternal)
				{
					if($Round_Robin)
					{
						$Distribution = "With (Distribution = Round_Robin, Heap)";
					}
					else
					{
				$Distribution = "With (Distribution = Hash(" + $DistColumn + "), Heap)";
						}
				$write.WriteLine("WITH (DATA_SOURCE = $PolybaseDatasource, ");
				$write.WriteLine("          LOCATION = N'$PloybaseFileLocation$TableName',");
				$write.WriteLine("          FILE_FORMAT = $PolybaseFileFormat,");
				$write.WriteLine("          REJECT_TYPE = $RejectType,");
				$write.WriteLine("          REJECT_VALUE = $RejectValue");
				$write.WriteLine(")");
						
				#$write.WriteLine($WithClausePolybase);
				$write.WriteLine("");
				$write.WriteLine("--- VERIFY EXTERNAL DATA ---");
				$write.WriteLine("");
				$write.WriteLine("SELECT TOP 10 * FROM [dbo].[EXT_$TableName];");
				$write.WriteLine("");
				}
				if($CreateTable)
				{
				$write.WriteLine("--- CREATE DW TABLE TO TEST SQL SELECTS WITHOUT DATA ---");
				$write.WriteLine("")
				$write.WriteLine("if Exists(select 1 from sys.tables where name = '$TableName') Drop Table [dbo].[$TableName]");
				#$write.WriteLine("")
				#$write.WriteLine("")

				#$write.WriteLine("If Exists(select 1 from sys.tables where name = '$TableName') Drop External Table [dbo].[$TableName]");
				$write.WriteLine("CREATE TABLE [dbo].[$TableName]");
				
				foreach($Column in $ColumnList)
					{
						$write.WriteLine($Column);
					}
				#$write.WriteLine("$ColumnList");
				if($Round_Robin)
					{
						$write.WriteLine("with (Distribution = Round_Robin, HEAP)");
					}
					else
					{
						$write.WriteLine("with (Distribution = Hash($DistColumn), HEAP)");
					}
				$write.WriteLine("");
				}
				if($CreateCTAS)
				{
				$write.WriteLine("--- LOAD DATA VIA CTAS ---");
				$write.WriteLine("");
				$write.WriteLine("")
				$write.WriteLine("if Exists(select 1 from sys.tables where name = '$TableName') Drop Table [dbo].[$TableName]");
				$write.WriteLine("Declare @start datetime")
				$write.WriteLine("Set @start = getdate()")
				$write.WriteLine("");
				$test = "Create table $TableName $Distribution As"
				$write.WriteLine("Create table $TableName $Distribution As"); 
				$write.WriteLine("Select * from [dbo].[Ext_$TableName] option (label = 'Data Load for Table: $TableName At: $DWUSetting')");
				$write.WriteLine("")
				$write.WriteLine("Insert into Load_Times(Tablename, Duration, DWU, Load_Comment,  CreateDate) Select '$TableName', DateDiff(ss, @start, getdate()), '$DWUSetting', '$LoadTableComment', getdate()")
				$write.WriteLine("");
				}
				if($CreateIndex)
				{
				$write.WriteLine("--- CREATE THE INDEX ---");
				$write.WriteLine("")
				$write.WriteLine("Create Clustered ColumnStore Index IdxCCI_$TableName on $TableName");
				$write.WriteLine("")
				}
				if($CreateValidateData)
				{
				$write.WriteLine("--- VALIDATE THE LOADED DATA ---")
				$write.WriteLine("")
				$write.WriteLine("select count(*) as Row_Count, '$TableName' as TableName from [dbo].[$TableName]");
				$write.WriteLine("")
				}
				break;
			}
			Else
			{
				if($line -match "character varying")
				{
					$line = $line.Replace("character varying", "varchar");
				}
				elseif($line -match "timestamp")
				{
					$line = $line.Replace("timestamp", "datetime2");
				}
				elseif ($line -match "byteint")
				{
					$line = $line.Replace("byteint", "smallint");
				}
				elseif ($line -match "Constraint")
				{
					$line = "";
				}
				elseif($line -match "boolean")
				{
					$line = $line.Replace("boolean", "bit");
				}
				if($line -match "default")
				{
					
					$position = $line.IndexOf("default");
					if($line -match ",")
					{
						$line = $line.Substring(0, $position) + ",";
					}
					else
					{
						$line = $line.Substring(0, $position);
					}
				}
				#if($line -match "::")
				#{
				#	$position = $line.IndexOf("::");
				#	if($line -match ",")
				#	{
				#		$line = $line.Substring(0, $position) + ",";
				#	}
				#	else
				#	{
				#		$line = $line.Substring(0, $position);
				#	}
				#}
				#if($line -match "NOW()")
				#{
				#	Write-Host "$TableName contains a default for NOW() in Column: $line"
				#	$position = $line.IndexOf("default");
				#	if($line -match ",")
				#	{
				#		$line = $line.Substring(0, $position) + ",";
				#	}
				#	else
				#	{
				#		$line = $line.Substring(0, $position) + "";
				#	}
				#}
				If($FirstTable -eq 1) 
				{
					$ColumnList.Add($line);
				}
				
				if($CreateExternal)
				{
				$write.WriteLine($line);
				}
				$FirstTable = 1
			}
			$line = $read.ReadLine();
		}
		
	}
	Else
	{
		#Write-Host "Skip Line"
		$FirstTable = 0
		If($FileOpen)
		{
			$write.Close()
			$write.Dispose()
			$FileOpen = $false
		}
	}
	
}
$read.Close()
$read.Dispose()
If($FileOpen)
	{
		$write.Close()
		$write.Dispose()
	}
