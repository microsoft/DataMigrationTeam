#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# $Id: installora2pg.ps1 16 2019-10-14 22:33:44Z bpahlawa $
# $Date: 2019-10-15 09:33:44 +1100 (Tue, 15 Oct 2019) $
# $Revision: 16 $
# $Author: bpahlawa $
#

#Parameter to be passed by this program when running as administrator
param (
    [string]$Flag = 0
)

#location to install git
$GitFolder="C:\github";
#repository location to clone ora2pg source
$ora2pgGit="https://github.com/darold/ora2pg.git";
#temp directory to install ora2pg
$ora2pgTemp="C:\ora2pgTemp";
#location to install ORACLE_HOME instant client
$Global:oraclehome="C:\instantclient_12_2";
#location to write a log file
$Global:Logfile = "c:\installora2pg.log"

#function to display message and also write to a logfile
Function Write-OutputAndLog
{
   Param ([string]$Message)
   write-host "$message"
   Add-content "$Global:Logfile" -value "$message"
}

#function to install perl
Function Install-Perl {
  #installation path parameter
  Param(
    [string] $installationPath
  )

  #Browse the web where perl is downloaded
  $urlperl="http://strawberryperl.com/"
  Write-OutputAndLog "Browsing $urlperl"
  

  #Get version of latest strawberry perl from the web
  Write-OutputAndLog "Getting version of strawberry-perl..."
  $RetVal = ( Invoke-WebRequest $urlperl ) -Match "href=.*strawberry-perl-([0-9.]+).*" 
  $Version = $Matches.1

  #check whether perl version can be gathered from the web
  if ($retval -eq $true)
  {
      Write-OutputAndLog "Latest version is $Version"
	  #url link where the perl installation file can be downloaded
      $url = ("http://strawberryperl.com/download/$Version/strawberry-perl-$Version-64bit.msi" -f $Version);
      
  }
  else
  {
      #unable to get the file from web or website may be down
      Write-OutputAndLog "Unable to get the strawberry perl version from strawberryperl website..."
	  write-outputAndLog "........Press any key to exit............"
	  $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
      exit
  }

  #initialize options as an array
  $options = @();

  #check whether installationPath is available, if it is then install perl
  if ($installationPath) {
    $options += ('INSTALLDIR="{0}"' -f $installationPath);
  }
  #execute install perl
  Install-FromMsi -Name 'perl' -Url $url -Options $options;
}

#function to install msi application
Function Install-FromMsi {
    #required parameters are name and url
    Param(
        [Parameter(Mandatory)]
        [string] $name,
        [Parameter(Mandatory)]
        [string] $url,
        [Parameter()]
        [switch] $noVerify = $false,
        [Parameter()]
        [string[]] $options = @()
    )

    #once it is downloaded it will be stored in the location that is assigned to this variable
    $installerPath = Join-Path ([System.IO.Path]::GetTempPath()) ('{0}.msi' -f $name);

    #check whether msi application has been installed
	#Supress error
    $ErrorActionPreference = 'SilentlyContinue'

    #Execute the command even if it doesnt exist
    $result = Invoke-Expression -command "$name --version"
    $ErrorActionPreference = 'Continue'

    #if the $result variable is null then the command isnt installed 
	#otherwise it will display $name has been installed and return to main program
    if ($result -ne $null)
    {
        write-outputAndLog "$name has been installed.."
        return;
    }
    else
    {
        Write-OutputAndLog "Will be downloading $name from $url"
    }

    #if the $installerpath file isnt available then download the file
    if (  ( Test-Path -path $installerPath ) -eq  $false)
    {
       Write-OutputAndLog ('Downloading {0} installer from {1} ..' -f $name, $url);
       Invoke-WebRequest -Uri $url -Outfile $installerPath;
       Write-OutputAndLog ('Downloaded {0} bytes' -f (Get-Item $installerPath).length);
    }
    else
    {
       Write-OutputAndLog "File $InstallerPath has been downloaded..." 
    }

    #add necessary arguments to install quietly
    $args = @('/i', $installerPath, '/quiet', '/qn');
    $args += $options;

    #display message
    Write-OutputAndLog ('Installing {0} ...' -f $name);
    Write-OutputAndLog ('msiexec {0}' -f ($args -Join ' '));

    #execute installation
    Start-Process msiexec -Wait -ArgumentList $args;

    # Update path
    $env:PATH = [Environment]::GetEnvironmentVariable('PATH', [EnvironmentVariableTarget]::Machine);

    #verify whether the application is installed successfully
    if (!$noVerify) {
        Write-OutputAndLog ('Verifying {0} install ...' -f $name);
        $verifyCommand = (' {0} --version' -f $name);
        Write-OutputAndLog $verifyCommand;
        Invoke-Expression $verifyCommand;
    }

    #remove the installation file
    Write-OutputAndLog ('Removing {0} installer ...' -f $name);
    Remove-Item $installerPath -Force;

    Write-OutputAndLog ('{0} install complete.' -f $name);
}


#function to install from Exe file
Function Install-FromExe {
    Param(
        [Parameter(Mandatory)]
        [string] $name,
        [Parameter(Mandatory)]
        [string] $url,
        [Parameter()]
        [switch] $noVerify = $false,
        [Parameter(Mandatory)]
        [string[]] $options = @()
    )

    #download file will be store in the location that is pointed by $installerPath
    $installerPath = Join-Path ([System.IO.Path]::GetTempPath()) ('{0}.exe' -f $name);

    #if this is git installation then check whether the destination folder is set
    if ( (Test-path -path $GitFolder) -eq $True) 
    {
	    #goto $gitfolder\bin
        Set-location "$GitFolder\bin"
		#supress error
        $ErrorActionPreference = 'SilentlyContinue';
        #check whether git has been installed
		$result = Invoke-Expression -command ".\$name --version"

        write-outputAndLog "result is $result"
        $ErrorActionPreference = 'Continue';
        

        if ($result -ne $null)
        {
            write-outputAndLog "$name has been installed.."
            return;
        }
        else
        {
           write-outputAndLog "$name does not exist..."
        }
    }
    #check whether the file is available, if it is not then download the file from the given url
    if (  ( Test-Path -path $installerPath ) -eq  $false)
    {
        Write-OutputAndLog ('Downloading {0} installer from {1} ..' -f $name, $url);
        Invoke-WebRequest -Uri $url -outFile $installerPath;
        Write-OutputAndLog ('Downloaded {0} bytes' -f (Get-Item $installerPath).length);

        Write-OutputAndLog ('Installing {0} ...' -f $name);
        Write-OutputAndLog ('{0} {1}' -f $installerPath, ($options -Join ' '));

    }
    else
    {
	   #display message that file has been downloaded 
       Write-OutputAndLog "File $InstallerPath has been downloaded..."
    }

    #execute installation process
    Start-Process $installerPath -Wait -ArgumentList $options;

    # Update path
     $env:PATH = "$([Environment]::GetEnvironmentVariable('PATH', [EnvironmentVariableTarget]::Machine));{0}\bin" -f $GitFolder;

    #verify whether the installation is successfull
    if (!$noVerify) {
        Write-OutputAndLog ('Verifying {0} install ...' -f $name);
        $verifyCommand = (' {0} --version' -f $name);
        Write-OutputAndLog $verifyCommand;
        Invoke-Expression $verifyCommand;
    }

    #Remove temp file
    Write-OutputAndLog ('Removing {0} installer ...' -f $name);
    Remove-Item $installerPath -Force;

    Write-OutputAndLog ('{0} install complete.' -f $name);
}

#function to remove all tempfiles under c:/windows/temp
Function Remove-TempFiles {
    $tempFolders = @($env:temp, 'C:/Windows/temp')

    Write-OutputAndLog 'Removing temporary files';
    $filesRemoved = 0;
  
    foreach ($folder in $tempFolders) {
        $files = Get-ChildItem -Recurse -Force -ErrorAction SilentlyContinue $folder;

        foreach ($file in $files) {
            try {
                Remove-Item $file.FullName -Recurse -Force -ErrorAction Stop
                $filesRemoved++;
            }
            catch {
                Write-OutputAndLog ('Could not remove file {0}' -f $file.FullName)
            }
        }
    }

    Write-OutputAndLog ('Removed {0} files from temporary directories' -f $filesRemoved)
}

#function to check internet connection
Function Check-Internet()
{

    $ErrorActionPreference = 'SilentlyContinue'
	#check connection to microsoft.com, this is to ensure that the location where the script is run has internet connection
    $Result = (Invoke-WebRequest "http://microsoft.com" -ErrorAction SilentlyContinue)
    $ErrorActionPreference = 'Continue'

    #if $result isnt null then internet is available, otherwise exit out
    if ($Result -eq $null)
    {
    
        write-outputAndLog "Internet is not available..."
		write-outputAndLog "........Press any key to exit............"
		$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
        exit
    }

}

#function to check oracleclient
Function Check-OracleClient()
{
     #parameter for instant client path
     Param(
        [String] $OracleInstallPath
      )

    #check whether oracle instant client/oracle client has been installed by searching oci.dll
	if ($oracleinstallpath -ne $null)
    {
	   #search oci.dll from location $oracleinstallpath
       write-outputAndLog "Searching oci.dll from Directory $oracleinstallpath..."
       $result = Get-Childitem –Path "$oracleinstallpath" -Include oci.dll -Recurse -ErrorAction SilentlyContinue 
       
    }
    else
    {
	   #Search oci.dll from all logical drives recursively
       write-outputAndLog "Searching oci.dll from all Logical drives..."
       foreach ( $Disk in (Get-Volume | where { $_.DriveLetter -ne $null })) {
           $result = Get-childitem -path "$($Disk.DriveLetter):\" -include oci.dll -recurse -erroraction SilentlyContinue 
       }

       

    }
	
	#if no oci.dll to be found, then this script will display message where to download the oracle instant client
	if ($result -eq $null)
    {
	    #url of base oracle instant client and sdk
        $baseoracle = "https://download.oracle.com/otn/nt/instantclient/122010/instantclient-basic-windows.x64-12.2.0.1.0.zip"
        $sdkoracle = "https://download.oracle.com/otn/nt/instantclient/122010/instantclient-sdk-windows.x64-12.2.0.1.0.zip"

        #get the file name
        $baseoraclezipfile=split-path -path $baseoracle -leaf
        $sdkoraclezipfile=Split-Path -path $sdkoracle -leaf
		
		#check if those 2 files are available
        if ( (Test-Path -path "$Global:ScriptDir\$baseoraclezipfile" ) -eq $false -or (Test-Path -path "$Global:ScriptDir\$sdkoraclezipfile" ) -eq $false  )
        {
		    #one or both files do not exist, therefore display the following messages
            write-outputAndLog "Oracle client and SDK are required..."
            write-outputAndLog "Please download base Instantclient from:`n$baseoracle"
            write-outputAndLog "and`n$sdkoracle"
            write-outputAndLog "Please download the 2 files and extract both to $Global:oraclehome"
		    write-outputAndLog "or put those 2 files in zip format at the same location of this script."
		    write-outputAndLog "........Press any key to exit............"
		    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
            exit
        }
        else
        {
		    #those files exist, therefore extract them
            write-outputAndLog "Extracting file $Global:ScriptDir\$baseoraclezipfile ..."
            Expand-Archive -LiteralPath "$Global:ScriptDir\$baseoraclezipfile" -DestinationPath "c:\"
            write-outputAndLog "Extracting file $Global:ScriptDir\$sdkoraclezipfile ..."
            Expand-Archive -Literalpath "$Global:ScriptDir\$sdkoraclezipfile" -DestinationPath "c:\"
        }
    }
    else
    {
	    #found oci.dll somewhere which means that oracle client is installed
        write-outputAndLog "Found OCI.dll in $($result.FullName)"
        $Global:oraclehome = Split-Path -path $result.FullName
    }


}

#function to install ora2pg
Function install-Ora2Pg()
{
    #set parent directory to c:\
    cd c:\
    write-outputAndLog "Setting environment variable..."
	#Add $gitfolder to path environment variable so git can be run
    $env:PATH = "$([Environment]::GetEnvironmentVariable('PATH', [EnvironmentVariableTarget]::Machine));{0}\bin" -f $GitFolder;

    write-outputAndLog "Checking whether ora2pg has been installed..."
	#supress error
    $ErrorActionPreference = 'SilentlyContinue'
	#execute ora2pg --version even if it doesnt exist
    if ( (Invoke-expression "ora2pg --version") -eq $null)
    {
	    #unsupress error
        $ErrorActionPreference = 'Continue'
        write-outputAndLog "ora2pg does not exist..."
		
		#if there is ora2pg on tempfile then delete it
        if ((Test-path -path $ora2pgTemp) -eq $True)
        {
            Remove-item $ora2pgTemp -Recurse -Force
        }
        write-outputAndLog "Cloning git repo to $ora2pgTemp ..."

        #supress error
        $ErrorActionPreference = 'SilentlyContinue'
		#execute git clone ora2pg even if it doesnt exist (assuming it does exist)
        Invoke-expression -command "git clone $ora2pgGit $ora2pgTemp" 
		#unsupress error
        $ErrorActionPreference = 'Continue'

        #Check whether ora2pg has been downloaded
        if ( (Test-path -path $ora2pgTemp) -eq $True)
        {
		   #this is to force ora2pg recompilation just incase there is a problem with the previous step
           cd $ora2pgTemp
           $ErrorActionPreference = 'SilentlyContinue'
           perl Makefile.PL
           gmake
           gmake install
           $ErrorActionPreference = 'Continue'
           cd ..
           Remove-Item $ora2pgtemp -Recurse -Force
        }
    }
    else
    {
	    #display message that ora2pg has been installed
        write-outputAndLog "ora2pg is currently existing.. in order to upgrade it, please delete ora2pg.bat under strawberryperl bin directory.."
        return
    }

}

#function to install perl library from CPAN
Function Install-PerlLib()
{
    Param(
        [Parameter(Mandatory)]
        [string] $name
        )

    write-outputAndLog "Executing cpan to install $name ..."
    $DirName = $name.replace("::","-")
    
    #check if the library.pm exists, if it is then delete the library.pm before it can be re-installed
    foreach ( $Disk in (Get-Volume | where { $_.DriveLetter -ne $null })) {
           $result = Get-childitem -path "$($Disk.DriveLetter):\strawberry" -Include "$Dirname*" -Exclude ("$Dirname*.pm","$Dirname*.gz") -recurse -erroraction SilentlyContinue 
           if ($result -ne $null)
           {
               write-outputAndLog "Removing item $Result .."
               Remove-item -path $Result -recurse -force
           }
       }

    
    #exeucte cpan 
    invoke-Expression -command "cpan -i $name"
    set-location "$result"
	#supress error
    $ErrorActionPreference = 'SilentlyContinue'
	#install perl library and if it is oracle it will force to use version 12.2.0
    perl Makefile.PL -V 12.2.0
    gmake
    gmake install
    $ErrorActionPreference = 'Continue'
    cd ..
    
}

    #this is an entry point of this powershell script
	
    #get the script name
	$TheScriptName = $MyInvocation.MyCommand.Name

    #check whether this script has been running
	$handle = get-process | where { $_.name -like 'powershell*' }

    #check if the parameter has been passed to this scirpt
	if ( $Flag -eq 0 -and $handle.count -lt 4 )
	{
	    #if not then execute this script as administrator
		Start-process Powershell -verb runas -ArgumentList "-file `"$($MyInvocation.MyCommand.Definition)`" 1"
		$Env:ScriptName="$TheScriptName"
		#this will exit out but it will spawn this script again with administrator privilege
	}
	else
	{
	    #get the script directory location
        $Global:ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
		#execute the functions to check internet, install perl and oracle client
		Check-Internet
		install-perl
		Check-OracleClient "$Global:oraclehome"

        #install portable git from the following url
		Install-FromExe -name git -url https://github.com/git-for-windows/git/releases/download/v2.23.0.windows.1/PortableGit-2.23.0-64-bit.7z.exe "-o $GitFolder -y"

        #set ORACLE_HOME and LD_LIBRARY_PATH environment variables
		$env:ORACLE_HOME="$Global:oraclehome"
		$env:LD_LIBRARY_PATH="$Global:oraclehome"
		 
		#Check whether Oracle.pm is installed, if not then execute install perl library for DBD::Oracle
        $result = Get-ChildItem -path "C:\strawberry" -Include "Oracle.pm" -recurse
        if ($result -eq $null)
		{
            install-perllib "DBD::Oracle"
        }
		#check whether Pg.om is installed, if not then execute install per library for DBD::Pg
        $result = Get-ChildItem -path "C:\strawberry" -Include "Pg.pm" -recurse
        if ($result -eq $null)
        {
            install-perllib "DBD::Pg"
        }
		#install ora2pg
		install-Ora2Pg
        Write-OutputAndLog "`n=====================================================================================================`n`n"
		write-outputAndLog "........Press any key to exit............"
		#requires press any key to exit
		$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');

}

