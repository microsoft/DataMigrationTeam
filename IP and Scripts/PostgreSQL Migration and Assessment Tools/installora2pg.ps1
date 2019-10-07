#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# $Id: installora2pg.ps1 14 2019-10-07 12:00:52Z bpahlawa $
# $Date: 2019-10-07 23:00:52 +1100 (Mon, 07 Oct 2019) $
# $Revision: 14 $
# $Author: bpahlawa $
#

param (
    [string]$Flag = 0
)

$GitFolder="C:\github";
$ora2pgGit="https://github.com/darold/ora2pg.git";
$ora2pgTemp="C:\ora2pgTemp";
$Global:oraclehome="C:\instantclient_12_2";
$Global:Logfile = "c:\installora2pg.log"


Function Write-OutputAndLog
{
   Param ([string]$Message)
   write-host "$message"
   Add-content "$Global:Logfile" -value "$message"
}

Function Install-Perl {
  Param(
    [string] $installationPath
  )

  #Browse the web
  $urlperl="http://strawberryperl.com/"
  Write-OutputAndLog "Browsing $urlperl"
  

  #Get version of latest strawberry perl from the web
  Write-OutputAndLog "Getting version of strawberry-perl..."
  $RetVal = ( Invoke-WebRequest $urlperl ) -Match "href=.*strawberry-perl-([0-9.]+).*" 
  $Version = $Matches.1

  
  if ($retval -eq $true)
  {
      Write-OutputAndLog "Latest version is $Version"
      $url = ("http://strawberryperl.com/download/$Version/strawberry-perl-$Version-64bit.msi" -f $Version);
      
  }
  else
  {
      Write-OutputAndLog "Unable to get the strawberry perl version from strawberryperl website..."
      exit
  }


  $options = @();

  if ($installationPath) {
    $options += ('INSTALLDIR="{0}"' -f $installationPath);
  }

  Install-FromMsi -Name 'perl' -Url $url -Options $options;
}

Function Install-FromMsi {
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

    $installerPath = Join-Path ([System.IO.Path]::GetTempPath()) ('{0}.msi' -f $name);

    #check whether perl has been installed
    $ErrorActionPreference = 'SilentlyContinue'

    $result = Invoke-Expression -command "$name --version"
    $ErrorActionPreference = 'Continue'

    if ($result -ne $null)
    {
        write-outputAndLog "$name has been installed.."
        return;
    }
    else
    {
        Write-OutputAndLog "Will be downloading $name from $url"
    }

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

    $args = @('/i', $installerPath, '/quiet', '/qn');
    $args += $options;

    Write-OutputAndLog ('Installing {0} ...' -f $name);
    Write-OutputAndLog ('msiexec {0}' -f ($args -Join ' '));

    Start-Process msiexec -Wait -ArgumentList $args;

    # Update path
    $env:PATH = [Environment]::GetEnvironmentVariable('PATH', [EnvironmentVariableTarget]::Machine);

    if (!$noVerify) {
        Write-OutputAndLog ('Verifying {0} install ...' -f $name);
        $verifyCommand = (' {0} --version' -f $name);
        Write-OutputAndLog $verifyCommand;
        Invoke-Expression $verifyCommand;
    }

    Write-OutputAndLog ('Removing {0} installer ...' -f $name);
    Remove-Item $installerPath -Force;

    Write-OutputAndLog ('{0} install complete.' -f $name);
}


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

    
    $installerPath = Join-Path ([System.IO.Path]::GetTempPath()) ('{0}.exe' -f $name);

    
    if ( (Test-path -path $GitFolder) -eq $True) 
    {
        Set-location "$GitFolder\bin"
        $ErrorActionPreference = 'SilentlyContinue';
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
       Write-OutputAndLog "File $InstallerPath has been downloaded..."
    }

    Start-Process $installerPath -Wait -ArgumentList $options;

    # Update path
     $env:PATH = "$([Environment]::GetEnvironmentVariable('PATH', [EnvironmentVariableTarget]::Machine));{0}\bin" -f $GitFolder;

    if (!$noVerify) {
        Write-OutputAndLog ('Verifying {0} install ...' -f $name);
        $verifyCommand = (' {0} --version' -f $name);
        Write-OutputAndLog $verifyCommand;
        Invoke-Expression $verifyCommand;
    }

    Write-OutputAndLog ('Removing {0} installer ...' -f $name);
    Remove-Item $installerPath -Force;

    Write-OutputAndLog ('{0} install complete.' -f $name);
}

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

Function Get-Poshgit()
{
    Install-Module -Name posh-git -Force
    Get-Module -Name posh-git -ListAvailable
}

Function Check-Internet()
{

    $ErrorActionPreference = 'SilentlyContinue'
    $Result = (Invoke-WebRequest "http://microsoft.com" -ErrorAction SilentlyContinue)
    $ErrorActionPreference = 'Continue'

    if ($Result -eq $null)
    {
    
        write-outputAndLog "Internet is not available..."
        exit
    }

}

Function Check-OracleClient()
{
     Param(
        [String] $OracleInstallPath
      )

    
    if ($oracleinstallpath -ne $null)
    {
       write-outputAndLog "Searching oci.dll from Directory $oracleinstallpath..."
       $result = Get-Childitem –Path "$oracleinstallpath" -Include oci.dll -Recurse -ErrorAction SilentlyContinue 
       
    }
    else
    {
       write-outputAndLog "Searching oci.dll from all Logical drives..."
       foreach ( $Disk in (Get-Volume | where { $_.DriveLetter -ne $null })) {
           $result = Get-childitem -path "$($Disk.DriveLetter):\" -include oci.dll -recurse -erroraction SilentlyContinue 
       }

       

    }
	
	if ($result -eq $null)
    {
        $baseoracle = "https://download.oracle.com/otn/nt/instantclient/122010/instantclient-basic-windows.x64-12.2.0.1.0.zip"
        $sdkoracle = "https://download.oracle.com/otn/nt/instantclient/122010/instantclient-sdk-windows.x64-12.2.0.1.0.zip"

        $baseoraclezipfile=split-path -path $baseoracle -leaf
        $sdkoraclezipfile=Split-Path -path $sdkoracle -leaf
		
        if ( (Test-Path -path "$Global:ScriptDir\$baseoraclezipfile" ) -eq $false -or (Test-Path -path "$Global:ScriptDir\$sdkoraclezipfile" ) -eq $false  )
        {
		
            write-outputAndLog "Oracle client and SDK are required..."
            write-outputAndLog "Please download base Instantclient from:`n$baseoracle"
            write-outputAndLog "and`n$sdkoracle"
            write-outputAndLog "The above 2 files only a zipped files, extract both to $Global:oraclehome"
		    write-outputAndLog "or put those 2 files at the same location as this script"
		    write-outputAndLog "........Press any key to exit............"
		    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
            exit
        }
        else
        {
            write-outputAndLog "Extracting file $Global:ScriptDir\$baseoraclezipfile ..."
            Expand-Archive -LiteralPath "$Global:ScriptDir\$baseoraclezipfile" -DestinationPath "c:\"
            write-outputAndLog "Extracting file $Global:ScriptDir\$sdkoraclezipfile ..."
            Expand-Archive -Literalpath "$Global:ScriptDir\$sdkoraclezipfile" -DestinationPath "c:\"
        }
    }
    else
    {
        write-outputAndLog "Found OCI.dll in $($result.FullName)"
        $Global:oraclehome = Split-Path -path $result.FullName
    }


}

Function install-Ora2Pg()
{
    cd c:\
    write-outputAndLog "Setting environment variable..."
    $env:PATH = "$([Environment]::GetEnvironmentVariable('PATH', [EnvironmentVariableTarget]::Machine));{0}\bin" -f $GitFolder;

    write-outputAndLog "Checking whether ora2pg has been installed..."
    $ErrorActionPreference = 'SilentlyContinue'
    if ( (Invoke-expression "ora2pg --version") -eq $null)
    {
        $ErrorActionPreference = 'Continue'
        write-outputAndLog "ora2pg does not exist..."
        if ((Test-path -path $ora2pgTemp) -eq $True)
        {
            Remove-item $ora2pgTemp -Recurse -Force
        }
        write-outputAndLog "Cloning git repo to $ora2pgTemp ..."

        $ErrorActionPreference = 'SilentlyContinue'
        Invoke-expression -command "git clone $ora2pgGit $ora2pgTemp" 
        $ErrorActionPreference = 'Continue'

        if ( (Test-path -path $ora2pgTemp) -eq $True)
        {
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
        write-outputAndLog "ora2pg is currently existing.. in order to upgrade it, please delete ora2pg.bat under strawberryperl bin directory.."
        return
    }

}

Function Install-PerlLib()
{
    Param(
        [Parameter(Mandatory)]
        [string] $name
        )

    write-outputAndLog "Executing cpan to install $name ..."
    $DirName = $name.replace("::","-")
    

    foreach ( $Disk in (Get-Volume | where { $_.DriveLetter -ne $null })) {
           $result = Get-childitem -path "$($Disk.DriveLetter):\strawberry" -Include "$Dirname*" -Exclude ("$Dirname*.pm","$Dirname*.gz") -recurse -erroraction SilentlyContinue 
           if ($result -ne $null)
           {
               write-outputAndLog "Removing item $Result .."
               Remove-item -path $Result -recurse -force
           }
       }

    

    invoke-Expression -command "cpan -i $name"
    set-location "$result"
    $ErrorActionPreference = 'SilentlyContinue'
    perl Makefile.PL -V 12.2.0
    gmake
    gmake install
    $ErrorActionPreference = 'Continue'
    cd ..
    
}


	

	$TheScriptName = $MyInvocation.MyCommand.Name

	$handle = get-process | where { $_.name -like 'powershell*' }

	if ( $Flag -eq 0 -and $handle.count -lt 4 )
	{
		Start-process Powershell -verb runas -ArgumentList "-file `"$($MyInvocation.MyCommand.Definition)`" 1"
		$Env:ScriptName="$TheScriptName"
	}
	else
	{
        $Global:ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
		Check-Internet
		install-perl
		Check-OracleClient "$Global:oraclehome"

		Install-FromExe -name git -url https://github.com/git-for-windows/git/releases/download/v2.23.0.windows.1/PortableGit-2.23.0-64-bit.7z.exe "-o $GitFolder -y"

		$env:ORACLE_HOME="$Global:oraclehome"
		$env:LD_LIBRARY_PATH="$Global:oraclehome"
		 
        $result = Get-ChildItem -path "C:\strawberry" -Include "Oracle.pm" -recurse
        if ($result -eq $null)
		{
            install-perllib "DBD::Oracle"
        }
        $result = Get-ChildItem -path "C:\strawberry" -Include "Pg.pm" -recurse
        if ($result -eq $null)
        {
            install-perllib "DBD::Pg"
        }
		install-Ora2Pg
        Write-OutputAndLog "`n=====================================================================================================`n`n"

}

