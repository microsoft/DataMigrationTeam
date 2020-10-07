#Data SQL Ninja Engineering Team
#Get-Module SqlServer -ListAvailable

# Sign in to your Azure account
#Connect-AzAccount
Clear-Host
#Output folder for the log file
$Output=".\Output.log"

function Get-TimeStamp 
{
    return "[{0:MM/dd/yyyy} {0:HH:mm:ss}]" -f (Get-Date)
}

function fn_AddJobStep
{
    if ($Step.DatabaseName -notin "master","model","msdb","tempdb","distribution")
    {
        if ($Step.SubSystem.ToString() -eq 'TransactSql')
            {
                try
                {
                    $JobTargetGroupName = $Step.DatabaseName + "TG"
                    $TargetDatabase = $JobAgent | New-AzSqlElasticJobTargetGroup -Name $JobTargetGroupName -ErrorAction Stop
                    Write-Output "$(Get-TimeStamp) Creating target group $JobTargetGroupName..." | Tee-Object -FilePath $Output -Append
                    $TargetDatabase | Add-AzSqlElasticJobTarget -ServerName $AgentServerName.FullyQualifiedDomainName -DatabaseName $Step.DatabaseName | Out-Null
                    
                }
                catch{}
                Write-Output "$(Get-TimeStamp) Adding the job step $Step to $SQLJob..." | Tee-Object -FilePath $Output -Append
                $ElasticJob | Add-AzSqlElasticJobStep -Name $Step.Name -TargetGroupName $JobTargetGroupName -CredentialName $JobCred.CredentialName -CommandText $Step.Command -StepId $Step.ID -RetryAttempts $Step.RetryAttempts -InitialRetryIntervalSeconds ($Step.RetryInterval*60) | Out-Null
            }
        else
            {
                Write-Output "$(Get-TimeStamp) WARNING: The job step $Step for job $SQLJob will not be copied because it is not a Transact-SQL Script Type." | Tee-Object -FilePath $Output -Append
            }
    }
else 
    {
        Write-Output "$(Get-TimeStamp) WARNING: The job step $Step for job $SQLJob will not be copied because it is not linked to a user database." | Tee-Object -FilePath $Output -Append
    }
}


# Get the resource group - PVH_RG
$rgName = Read-Host "Please enter the resource group name"
$ResourceGroupName = Get-AzResourceGroup -Name $rgName -ErrorAction Stop

# Get the server - pvhdmj
$ServerName = Read-Host "Please enter your agent server name"
$AgentServerName=Get-AzSqlServer -ResourceGroupName $ResourceGroupName.ResourceGroupName -ServerName $ServerName -ErrorAction Stop

# Create or get the Elastic Job Agent
$AgentName = Read-Host "Please enter the name for your Elastic Job agent" #MyAgent
$JobAgent = Get-AzSqlElasticJobAgent -ResourceGroupName $ResourceGroupName.ResourceGroupName -ServerName $AgentServerName.ServerName -Name $AgentName

# Get the job Credential
#Make sure that the jobs_resource_manager has permission to read the database scoped credential
#GRANT CONTROL ON DATABASE SCOPED CREDENTIAL::myjobcred TO jobs_resource_manager
$JobCredentialName = Read-Host "Please enter the job credential"
$JobCred = $JobAgent | Get-AzSqlElasticJobCredential -Name $JobCredentialName

#Get the Job list of the SQL Server Instance 
$ServerInstance=Read-Host "Please enter the name of your SQL Server Instance" #localhost
$JobList = Get-SqlAgent -ServerInstance $ServerInstance | Get-SqlAgentJob | Where-Object {$_.Name -ne "syspolicy_purge_history"} 

Write-Output $JobList | Tee-Object -FilePath $Output -Append

Foreach($SQLJob in $JobList)
{
    if ($SQLJob.isenabled -eq $true)
    {
    foreach ($Step in $SQLJob.jobsteps)
        {
            try 
            {
                $ElasticJob = $JobAgent | New-AzSqlElasticJob -Name $SQLJob -Description $SQLJob.Description -ErrorAction Stop
                Write-Output "$(Get-TimeStamp) Creating the job with name $SQLJob..." | Tee-Object -FilePath $Output -Append
                fn_AddJobStep         
            }
            catch 
            {
                try
                {
                    fn_AddJobStep
                }
                Catch{}
            }
        }
    }
    else 
    {
         Write-Output "$(Get-TimeStamp) WARNING: The job $SQLJob will not be copied because it is disabled." | Tee-Object -FilePath $Output -Append
    }
}