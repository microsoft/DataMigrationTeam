<#

PLEASE REVIEW THE GENERATED SCRIPT CAREFULLY BEFORE APPLYING IT TO A PRODUCTION SYSTEM
Warranty: This script is provided on as "AS IS" basis and there are no warranties, express or implied, including, 
but not limited to implied warranties of merchantability or fitness for a particular purpose. USE AT YOUR OWN RISK. 

#>


$region="westus"
$vmtypes = Get-AzComputeResourceSku | where {$_.Locations.Contains($region)}
 
foreach($vmtype in $vmtypes)
{
    #Write-Output ($vmtype)[0].Capabilities
       
    $caps = ($vmtype)[0].Capabilities
    foreach ($cap in $caps)
    {
        if ($cap.Name.Contains("UltraSSDAvailable"))
        {            
            Write-Host $vmtype.LocationInfo[0].Location, $vmtype.Name, "Has Ultra SSD" 
        }
    }
} 
