# =================================================================================================================================================
# Scriptname: ScriptsObjectsTodSQL.ps1
# 
# Created: January, 2018
# Author: Andy Isley
# Company: Microsoft  
# 
# =================================================================================================================================================
# Description:
#       A function to use PDWScripter to script out MPP object by providing the required input values.
# =================================================================================================================================================
function ScriptObjects($ServerName
					,$UseIntegrated
					,$UserName
					,$Password 
					,$DatabaseName 
					,$WorkMode 
					,$OutputFolderPath 
					,$Mode 
					,$ObjectName
					,$ObjectsToScript)
{
	$cmd = 'C:\PDWScripter\dwScripter.exe -S:"' + $ServerName + '" -D:' + $DatabaseName
	
	if($UseIntegrated -eq 'Yes')
		{
			$cmd = $cmd + ' -E '
		}
	else
		{
			$cmd = $cmd + ' -U:' + $UserName + ' -P:' + $Password
		}

	$cmd = $cmd + ' -W:' + $WorkMode + ' -O:' + $OutputFolderPath + ' -F:' + $ObjectName + ' -M:' + $Mode + ' -Fo:Table '

	Write-Host $cmd
	Invoke-Expression $cmd

}

