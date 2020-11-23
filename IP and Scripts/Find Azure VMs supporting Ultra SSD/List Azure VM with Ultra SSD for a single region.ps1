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
