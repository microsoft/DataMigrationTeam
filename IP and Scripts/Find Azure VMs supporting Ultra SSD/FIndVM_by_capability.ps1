<#
.Synopsis
   Search for Virtual Machine SKUs by capabilities
.EXAMPLE
   .\FindVM_by_capability.ps1 -region ALL -capability 'UltraSSDAvailable'
.EXAMPLE
   .\FindVM_by_capability.ps1 -region eastus -capability 'LowPriorityCapable'
.INPUTS
   Region = the Azure region to search; use "ALL" for a global search (doesn't currently allow several regions to be selected)
   Capability = the capability to look for
.NOTES
   Run without parameter inputs, the script will query Azure for regions and capabilities and ask you to choose from the list
   Restriction; this uses out-gridview, so assumes this is being run interactively
   Will take a while before the output appears while the get-azcomputeresourceSKU cmdlet runs

   10th Dec 2020 updated to cater for UltraSSD availability which can be either by region or by zone within the region; see 
       https://docs.microsoft.com/en-us/azure/virtual-machines/disks-enable-ultra-ssd

PLEASE REVIEW THE GENERATED SCRIPT CAREFULLY BEFORE APPLYING IT TO A PRODUCTION SYSTEM
Warranty: This script is provided on as "AS IS" basis and there are no warranties, express or implied, including, 
but not limited to implied warranties of merchantability or fitness for a particular purpose. USE AT YOUR OWN RISK. 

#>
param ([string] $region='', [string] $capability='')

# list of the current Azure locations
$regionlist = get-azlocation | select Location, DisplayName | sort DisplayName
# initial list of all the VM types available
$vmtypelist = Get-AzComputeResourceSku | where resourcetype -eq 'virtualMachines'
# query this to get the capabilities that can be true or false
$capabilitieslist = $vmtypelist | select -ExpandProperty capabilities | where {$_.Value -in 'True','False'} | select Name -unique

# get values for the inputs; if these haven't been passed as parameters, ask for them interactively
$region     = if ($region -ne '')     {$region}     else {$regionlist | Out-GridView -PassThru -Title "Pick the region to search:" | select -expandproperty location}
$capability = if ($capability -ne '') {$capability} else {$capabilitieslist | Out-GridView -PassThru -Title "Pick the capability to search for:" | select -ExpandProperty name}

$avail_inRegion = $vmtypelist |
    where {$region -eq 'ALL' -or $_.Locations -Contains($region)} -PipelineVariable SKU | # filter for the region selected
    select -ExpandProperty capabilities | where {$_.Name -eq $capability -and $_.Value -eq 'True'} | # filter when the requested capability is true
    select `
        @{E={$SKU.Name};N="Name"}, `
        @{E={$SKU.Locations};N="Locations"}, `
        @{E={$SKU.Restrictions.reasoncode | select -Unique};N="Restrictions"}, ` 
        @{E={$_.name};N="Capability"}, `
        @{E={$_.value};N="Available"}, `
        @{E={($SKU.capabilities | where name -eq 'MemoryGB').value};N="MemoryGB"}, `
        @{E={($SKU.capabilities | where name -eq 'vCPUs').value};N="Cores"}, ` 
        @{E={$null};N="ZoneSpecific"}

$avail_inzone = $vmtypelist |
    where {$region -eq 'ALL' -or $_.Locations -Contains($region)} -PipelineVariable SKU | # filter for the region selected
    select -ExpandProperty LocationInfo -PipelineVariable Location | select -ExpandProperty ZoneDetails -PipelineVariable Zone | select -ExpandProperty capabilities | `
    where {$_.Name -eq $capability -and $_.Value -eq 'True'} | # filter when the requested capability is true
    select `
        @{E={$SKU.Name};N="Name"}, `
        @{E={$SKU.Locations};N="Locations"}, `
        @{E={$SKU.Restrictions.reasoncode | select -Unique};N="Restrictions"}, ` 
        @{E={$_.name};N="Capability"}, `
        @{E={$_.value};N="Available"}, `
        @{E={($SKU.capabilities | where name -eq 'MemoryGB').value};N="MemoryGB"}, `
        @{E={($SKU.capabilities | where name -eq 'vCPUs').value};N="Cores"},  ` 
        @{E={"Available in Zones " + (($Location.ZoneDetails.Name | sort) -join ",")};N="ZoneSpecific"}

$avail_inRegion + $avail_inzone | format-table name, locations, capability, memoryGB, Cores, ZoneSpecific, restrictions
# change the format-table above to a select if you want to pipe this out to a file, etc
# ...sample to filter the results for a specific number of cores and memory size
# $avail_inRegion + $avail_inzone | where {$_.cores -in 2..4 -and $_.MemoryGB -in 8..16} | ft