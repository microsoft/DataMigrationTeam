function RunSQLScriptFile 
{ 
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string]$ServerName, 
    [Parameter(Position=1, Mandatory=$false)] [string]$Database, 
    [Parameter(Position=2, Mandatory=$false)] [string]$Query, 
    [Parameter(Position=3, Mandatory=$false)] [string]$Username, 
    [Parameter(Position=4, Mandatory=$false)] [string]$Password,
	[Parameter(Position=5, Mandatory=$false)] [string]$SQLDWADIntegrated,
    [Parameter(Position=6, Mandatory=$false)] [Int32]$QueryTimeout=600, 
    [Parameter(Position=7, Mandatory=$false)] [Int32]$ConnectionTimeout=30, 
    [Parameter(Position=8, Mandatory=$false)] [string]$InputFile,#[ValidateScript({test-path $_})] , 
    [Parameter(Position=9, Mandatory=$false)] [ValidateSet("DataSet", "DataTable", "DataRow")] [string]$As="DataSet",
	[Parameter(Position=10, Mandatory=$false)] [string]$Variables=''
	#[Parameter(Position=11, Mandatory=$false)] [string]$SchemaName,
	#[Parameter(Position=12, Mandatory=$false)] [string]$TableName,
	#[Parameter(Position=13, Mandatory=$false)] [string]$DropIfExists,
	#[Parameter(Position=14, Mandatory=$false)] [string]$StatusLogFile #[ValidateScript({test-path $_})] 
    ) 
	try{
	$ReturnValues = @{}
	$ConnOpen = 'No'

    if ($InputFile) 
    { 
        $filePath = $(resolve-path $InputFile).path 
        $Query =  [System.IO.File]::ReadAllText("$filePath") 
    } 
	if ($Variables)
	{
		 $splitstr = $Variables.Split("=")
		 $search =  $splitstr[0]
		 $replace = $splitstr[1]
		 $Query = $Query.Replace($search,$replace)
	}
 
    #Initial Catalog=lasr-sqldwdb-dev1;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Authentication="Active Directory Integrated";
	
    #if ($Username) 
    #{ ADPass, ADInt, WinInt, SQLAuth
		if($SQLDWADIntegrated -eq 'ADINT')
		{
			#$ConnectionString = "Server={0};Database={1};User ID={2};Password={3};Trusted_Connection=False;Connect Timeout={4};Persist Security Info=False;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Authentication=Active Directory Integrated" -f $ServerName,$Database,$Username,$Password,$ConnectionTimeout
			$ConnectionString = "Server={0};Database={1};Trusted_Connection=False;Connect Timeout={2};Persist Security Info=False;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Authentication=Active Directory Integrated" -f $ServerName,$Database,$ConnectionTimeout
		}
		elseif($SQLDWADIntegrated -eq 'ADPASS')
		{
			$ConnectionString = "Server={0};Database={1};User ID={2};Password={3};Trusted_Connection=False;Connect Timeout={4};Persist Security Info=False;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Authentication=Active Directory Password" -f $ServerName,$Database,$Username,$Password,$ConnectionTimeout
		}
		elseif($SQLDWADIntegrated -eq 'SQLAUTH')
		{
			$ConnectionString = "Server={0};Database={1};User ID={2};Password={3};Trusted_Connection=False;Connect Timeout={4}" -f $ServerName,$Database,$Username,$Password,$ConnectionTimeout 
		} 
	#}	
		else 
		{ $ConnectionString = "Server={0};Database={1};Integrated Security=True;Connect Timeout={2}" -f $ServerName,$Database,$ConnectionTimeout } 
 
	$conn=new-object System.Data.SqlClient.SQLConnection
    $conn.ConnectionString=$ConnectionString 
     
    #Following EventHandler is used for PRINT and RAISERROR T-SQL statements. Executed when -Verbose parameter specified by caller 
    if ($PSBoundParameters.Verbose) 
    { 
        $conn.FireInfoMessageEventOnUserErrors=$true 
        $handler = [System.Data.SqlClient.SqlInfoMessageEventHandler] {Write-Verbose "$($_)"} 
        $conn.add_InfoMessage($handler) 
    } 
     
    $conn.Open() 
		$ConnOpen = 'YES'
    $cmd=new-object system.Data.SqlClient.SqlCommand($Query,$conn) 
    $cmd.CommandTimeout=$QueryTimeout 
    $ds=New-Object system.Data.DataSet 
    $da=New-Object system.Data.SqlClient.SqlDataAdapter($cmd) 

	
		[void]$da.fill($ds) 

		$ReturnValues.add('Status',"Success")
		$ReturnValues.add('Msg', $ErrVar)
    }
	Catch [System.Data.SqlClient.SqlException] # For SQL exception 
    { 
		$Err = $_ 

		$ReturnValues.add('Status',"Error")
		$ReturnValues.add('Msg', $Err)
		
		Write-Verbose "Capture SQL Error" 
		if ($PSBoundParameters.Verbose) {Write-Verbose "SQL Error:  $Err"}  

		#switch ($ErrorActionPreference.tostring()) 
		#{ 
		#	{'SilentlyContinue','Ignore' -contains $_} {} 
		#		'Stop' {     Throw $Err } 
		#        'Continue' { Throw $Err} 
		#        Default {    Throw $Err} 
		#} 
	} 
	Catch # For other exception 
	 {
	#	Write-Verbose "Capture Other Error"   

		$Err = $_ 

		$ReturnValues.add('Status',"Error")
		$ReturnValues.add('Msg', $Err)
		

	#	if ($PSBoundParameters.Verbose) {Write-Verbose "Other Error:  $Err"}  

	#	switch ($ErrorActionPreference.tostring()) 
	#	{'SilentlyContinue','Ignore' -contains $_} {} 
	#				'Stop' {     Throw $Err} 
	#				'Continue' { Throw $Err} 
	#				Default {    Throw $Err} 
	}  
	Finally 
	{ 
		#Close the connection 
		#if(-not $PSBoundParameters.ContainsKey('SQLConnection')) 
		#	{ 
			if($ConnOpen -eq 'YES') 
			{$ConnOpen = 'NO'
				$conn.Close()
				$cmd.Dispose()
				$ds.Dispose()
				$da.Dispose()
			}
				
			#}  
	}
    #switch ($As) 
    #{ 
    #    'DataSet'   { Write-Output ($ds) } 
    #    'DataTable' { Write-Output ($ds.Tables) } 
    #    'DataRow'   { Write-Output ($ds.Tables[0]) } 
    #} 
	#Write-Host $da
	if($ConnOpen -eq 'YES') 
			{$ConnOpen = 'NO'
				$conn.Close()}
	return $ReturnValues
	 
} 