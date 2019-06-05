#
# Name:     MoveLogins.ps1
#
# Author:   Mitch van Huuksloot, Data Migration Jumpstart Engineering Team, Microsoft Corporation
#
# Date:     April 23, 2019
#
# Version:  1.92.0
#
# Purpose:  Use this script for a typical move from on premises SQL Server to an Azure PaaS SQL Service. 
#           This script connects to a source SQL Server to capture logins, server roles, database users, database roles, role membership and selected object level permissions.
#           Set the connection strings for source and target and set the target database ($TargDatabase) to master for Azure SQL MI, and the actual database/DW name for Azure SQL DB and DW.
#           Depending on the target database type (Azure SQL DB, Azure SQL MI or Azure SQL DW), either logins or users are created for the target SQL DB/DW/MI. 
#           For an MI target, database users are also created for all databases processed (intersection of source and target databases).
#           Server and database level role membership is scripted as well as permissions on schemas, tables and columns. Server role level permissions are scripted, but note that NO other permissions are captured.
#           PLEASE REVIEW THE GENERATED SCRIPT CAREFULLY BEFORE APPLYING IT TO A PRODUCTION SYSTEM
#
# Notes and Limitations:
#           Complicated permissions hierarchies are not supported - we suggest you look at DMA
#           GRANTS WITH GRANT OPTION are not supported and many other nested permissions are not supported by this script.
#           Application Roles are not scripted.
#           Contained databases are not supported by this script. 
#           If you are going to use the AD lookup feature, you will need the Remote Server Administrator Tool enabled or installed - see https://www.microsoft.com/en-us/download/details.aspx?id=45520 for Windows 10
#
# Warranty: This script is provided on as "AS IS" basis and there are no warranties, express or implied, including, but not limited to implied warranties of merchantability or fitness for a particular purpose. USE AT YOUR OWN RISK. 
#
# Feedback: Please provide comments and feedback to the author at mitch.van.huuksloot@microsoft.com
#

# Variables that the User needs to set
$SrcConStr = "Server=localhost;Database=master;Integrated Security=True;Connect Timeout=120"
$TargConStr = "Server=servername.database.windows.net;Database={0};User Id={userid};Password={password};Connect Timeout=120"
$TargDatabase = "WideWorldImporters"
$Domain = "@microsoft.com"
$UseADLookup = 1      # do AD lookups to find actual email address, otherwise the script assumes the Windows IDs are DOMAIN\userid, which translate into userid@<$Domain> 
$DoSQLLogins = 1      # process SQL logins/users or only Windows logins/users
$QueryTimeout = 120

# SQL Queries
$ProdVersionQry = "select SERVERPROPERTY('ProductMajorVersion')"
$EngVersionQuy = "select SERVERPROPERTY('EngineEdition')"
$DBsQuery = "select [name] from sys.databases where [name] not in ('master','msdb', 'model', 'tempdb')"
$PrincipalQuery = "select p.[name], p.[type], p.default_database_name, p.default_language_name, p.sid, ISNULL(password_hash, 0) " +
                  "from sys.server_principals p left outer join sys.sql_logins l on (p.sid=l.sid) where p.[type] in ('S','U','G') "+
                  "and p.[name] <> 'sa' and upper(p.[name]) not like 'NT SERVICE%' and upper(p.[name]) not like 'NT AUTHORITY%' and p.[name] not like '##%' and p.[name] not like 'BUILTIN%' and p.is_disabled = 0"
$DestPrincipalQry = "select p.[name], p.[type] from sys.server_principals p where p.[type] in ('S', 'U', 'G') "+
                    "and p.[name] <> 'sa' and upper(p.[name]) not like 'NT SERVICE%' and upper(p.[name]) not like 'NT AUTHORITY%' and p.[name] not like '##%' and p.is_disabled = 0"
$DestLoginQry = "select [name], [type] from sys.sql_logins where [name] <> 'sa' and upper([name]) not like 'NT SERVICE%' and upper([name]) not like 'NT AUTHORITY%' and [name] not like '##%' and [name] not like 'BUILTIN%' and is_disabled = 0"
$DestUserQry = "select count(*) from {0}.sys.database_principals p where p.[name]='"
$SrvRolesQry = "select r.[name], o.[name], o.[type] from sys.server_principals r join sys.server_principals o on (r.owning_principal_id=o.principal_id) where r.[name] <> 'public' and r.[type]='R' and r.is_fixed_role=0 and r.is_disabled=0"
$DestSrvRoleQry = "select count(*) from sys.server_principals where [type]='R' and [name]='"
$NestedSrvRoleQry = "select r.[name], p.[name] from sys.server_role_members m join sys.server_principals r on (m.role_principal_id=r.principal_id) join sys.server_principals p on (m.member_principal_id=p.principal_id) where p.[type]='R'"
$SrvRolePermQry = "select p.state_desc, p.[permission_name] from sys.server_permissions p join sys.server_principals l on (p.grantee_principal_id=l.principal_id) where l.[type]='R' and not (p.[state]='G' and p.[type]='COSQ') and l.[name]='"
$DBRolesQry = "select p.[name], tp.[name], tp.[type] from {0}.sys.database_principals p join {0}.sys.database_principals tp on (p.owning_principal_id=tp.principal_id) where p.[type]='R' and p.is_fixed_role=0 and p.[name] != 'public'"
$DBRolesQryDest = "select count(*) from {0}.sys.database_principals p join {0}.sys.database_principals tp on (p.owning_principal_id=tp.principal_id) where p.[type]='R' and p.is_fixed_role=0 and p.[name] = '"
$DBNestRolesQry = "select r.[name], p.[name] from {0}.sys.database_role_members m join {0}.sys.database_principals r on (m.role_principal_id=r.principal_id) join {0}.sys.database_principals p on (m.member_principal_id=p.principal_id) where p.[type]='R'"
$SchemaQuery = "select d.name, default_schema_name from {0}.sys.database_principals d join master.sys.server_principals p on (d.sid=p.sid) where p.[name]='"
$SrvRoleQuery = "select r.[name] from sys.server_role_members m join sys.server_principals r on (m.role_principal_id=r.principal_id) join sys.server_principals p on (m.member_principal_id=p.principal_id) "+
                "where p.[name] ='"
$DBUserRoleQry = "select r.[name] from {0}.sys.database_role_members m join {0}.sys.database_principals r on (m.role_principal_id=r.principal_id) join {0}.sys.database_principals p on (m.member_principal_id=p.principal_id) "+
                "join master.sys.server_principals s on (s.sid=p.sid) where s.[name] = '"
$PermQuery = "select p.class_desc, case when class = 3 then s2.[name] else '['+s.[name]+'].['+o.[name]+']' end, case when class = 1 and p.minor_id <> 0 then c.name else ' ' end, p.permission_name, p.state_desc " +
             "from {0}.sys.database_permissions p join {0}.sys.database_principals dp on (p.grantee_principal_id = dp.principal_id) left join {0}.sys.objects o on (p.major_id=o.object_id) left join {0}.sys.schemas s on (o.schema_id=s.schema_id) "+
             "left join {0}.sys.schemas s2 on (p.major_id=s2.schema_id) left join {0}.sys.columns c on (p.major_id=c.object_id and p.minor_id=c.column_id) where class in (1, 3) and dp.[name]='"

# SQL Engine Editions
$SQLDB = 5
$SQLDW = 6
$SQLMI = 8

# Open connection to source database
$conn = New-Object System.Data.SqlClient.SQLConnection
$conn.ConnectionString = $SrcConStr
$conn.Open()

# Get Product version from Source
$cmd = New-Object System.Data.SqlClient.SqlCommand($ProdVersionQry,$conn)
$cmd.CommandTimeout = $QueryTimeout
$ProdVersion = $cmd.ExecuteScalar()

# Get database list from source
$srcdbs = @()
$cmd = New-Object System.Data.SqlClient.SqlCommand($DBsQuery,$conn)
$cmd.CommandTimeout = $QueryTimeout
$rdr = $cmd.ExecuteReader()
while ($rdr.Read())
{
    $srcdbs += $rdr.GetString(0)
}
$rdr.Close()

# Get SQL engine type of the target (we could hard code this if there is no connectivity)
$dconn = New-Object System.Data.SqlClient.SQLConnection
$dconn.ConnectionString=($TargConStr -f $TargDatabase)
$dconn.Open()
$dcmd = New-Object System.Data.SqlClient.SqlCommand($EngVersionQry,$dconn)
$dcmd.CommandTimeout = $QueryTimeout
$destversion = $dcmd.ExecuteScalar()

# Get database list from target - (this could be hard coded as one (DB/DW) or an array (MI) of databases to process)
$destdbs = @()
$dcmd.CommandText = $DBsQuery
$rdr = $dcmd.ExecuteReader()
while ($rdr.Read())
{
    $destdbs += $rdr.GetString(0)
}
$rdr.Close()

# Get the intersection of the two database lists - only process the databases on both source and target (not master, model, msdb, tempdb)
$Databases = $srcdbs | ?{$destdbs -contains $_}
if ($Databases.Length -eq 0)
{
    "There are no common databases between source and target servers"
    Exit
}

# Create second connection/command for inner loop on databases
$conn2 = New-Object System.Data.SqlClient.SQLConnection
$conn2.ConnectionString= $SrcConStr
$conn2.Open()
$cmd2 = New-Object System.Data.SqlClient.SqlCommand($SrvRoleQuery,$conn2)
$cmd2.CommandTimeout = $QueryTimeout

# Get logins from destination
$destlogins = @(@())
$dconnmaster = New-Object System.Data.SqlClient.SQLConnection
$dconnmaster.ConnectionString= ($TargConStr -f 'master')
$dconnmaster.Open()
if ($destversion -eq $SQLMI)
{
    $dmcmd = New-Object System.Data.SqlClient.SqlCommand($DestPrincipalQry,$dconnmaster) 
}
else
{
    $dmcmd = New-Object System.Data.SqlClient.SqlCommand($DestLoginQry,$dconnmaster) 
}
$rdr = $dmcmd.ExecuteReader()
while ($rdr.Read())
{
    $destlogins += ,($rdr.GetString(0), $rdr.GetString(1))
}
$rdr.Close()
$dconnmaster.Close()

# If using AD lookups, get a list of all domains in the AD forest (once)
if ($UseADLookup -eq 1)
{
    $domains = (Get-ADForest).Domains
}
$UserMap = @(@()) # accumulate Windows AD to AAD mapping

# Accumulate commands in array variables instead of dumping out as we go
$CreateLogins = @()
$ServerRoleMembers = @()
$DropDBUsers = @(@())
$CreateDBUsers = @(@())
$DBRoleMember = @(@())
$ObjectPerms = @(@())

# Main Loop - for each login (Principal) in the source SQL Server... (not including Roles and built in logins)
$cmd.CommandText = $PrincipalQuery
$rdr = $cmd.ExecuteReader()
while ($rdr.Read())
{
    $name = $rdr.GetString(0)
    $type = $rdr.GetString(1)
    $defaultdb = $rdr.GetString(2)
    $defaultlang = $rdr.GetString(3)
    $sid = $rdr.GetValue(4)
    $passhash = $rdr.GetValue(5)

    # If principal uses Windows Authentication (i.e. a User or Group)
    if (($type -eq 'G') -or ($type -eq 'U'))
    {
        $identity = ""
        $identity = $name.Split('\')
        $upn = ""
        if ($type -eq 'U') # Windows User
        {
            if ($UseADLookup -eq 1)
            {
                $server = ""
                foreach ($domain in $domains)    # User may be in another domain, so find the server we need to ask
                {
                    if ($domain.ToLower().StartsWith($identity[0].ToLower()))
                    {
                        $server = $domain
                    }
                }
                if ($server -ne "")
                {
                    $upn = (Get-ADUser -Identity $identity[1] -Server $server -Properties userPrincipalName).userPrincipalName
                }
                else
                {
                    $upn = (Get-ADUser -Identity $identity[1] -Properties userPrincipalName).userPrincipalName
                }
            }
            else 
            {
                $upn = $identity[1] + $Domain
            }
        }
        else # Windows Group
        {
            if ($UseADLookup -eq 1)
            {
                $server = ""
                foreach ($domain in $domains)     # Group may be in another domain, so find the server we need to ask
                {
                    if ($domain.ToLower().StartsWith($identity[0].ToLower()))
                    {
                        $server = $domain
                    }
                }
                if ($server -ne "")
                {
                    $upn = (Get-ADGroup -Identity $identity[1] -Server $server -Properties mail).mail
                }
                else
                {
                    $upn = (Get-ADGroup -Identity $identity[1] -Properties mail).mail
                }
            }
            else 
            {
                $upn = $identity[1] + $Domain
            }                
        }
        if ($upn -eq "")
        {
            $upn = $identity[1]  # security group without an email?
            "-- Warning: $name failed on Windows AD lookup - assuming that this is a security group ($upn) without an email address, but please review carefully"
        }
        $UserMap += ,($name, $upn)
        if ($destversion -eq $SQLMI)
        {
            $match = 0
            foreach ($login in $destlogins)
            {
                if ($login[0] -eq $upn -and $login[1] -eq $type)
                {
                    $match = 1
                }
            }
            if ($match -eq 0)
            {
                $CreateLogins += "CREATE LOGIN [$upn] FROM EXTERNAL PROVIDER WITH DEFAULT_DATABASE=[$defaultdb], DEFAULT_LANGUAGE=[$defaultlang]"
            }
            else
            {
                $CreateLogins += "-- CREATE LOGIN [$upn] FROM EXTERNAL PROVIDER WITH DEFAULT_DATABASE=[$defaultdb], DEFAULT_LANGUAGE=[$defaultlang] -- commented out because login already exists on the target"
            }
        }
    }
    elseif ($type -eq 'S' -and $DoSQLLogins -eq 1)
    {
        $passhashhex = "0x" + [System.BitConverter]::ToString($passhash).Replace('-','')
        $sidhex = "0x"+[System.BitConverter]::ToString($sid).Replace('-','')
        $match = 0
        foreach ($login in $destlogins)
        {
            if ($login[0] -eq $name -and $login[1] -eq $type)
            {
                $match = 1
            }
        }

        if ($match -eq 0)
        {
            $CreateLogins += "CREATE LOGIN [$name] WITH PASSWORD=$passhashhex HASHED, SID=$sidhex, DEFAULT_DATABASE=[$defaultdb], DEFAULT_LANGUAGE=[$defaultlang] -- password hash and SID support depends on target platform" 
        }
        else
        {
            $CreateLogins += "-- CREATE LOGIN [$name] WITH PASSWORD=$passhashhex HASHED, SID=$sidhex, DEFAULT_DATABASE=[$defaultdb], DEFAULT_LANGUAGE=[$defaultlang] -- commented out because login already exists on the target (password and SID support depends on target)"
        }
        $upn = $name
    }

    If ($type -ne 'S' -or ($type -eq 'S' -and $DoSQLLogins -eq 1))     # for all Windows prinicpals and potentially SQL principals (if the flag is on)
    {
        # Process Server Roles for this Principal
        $cmd2.CommandText = $SrvRoleQuery + $name + "'"
        $rdrrole = $cmd2.ExecuteReader()
        while ($rdrrole.Read())
        {
            if ($destversion -eq $SQLMI)
            {
                $ServerRoleMembers += ("ALTER SERVER ROLE [" + $rdrrole.GetString(0) + "] ADD MEMBER [$upn]")
            }
            else
            {
                $ServerRoleMembers += ("-- ALTER SERVER ROLE [" + $rdrrole.GetString(0) + "] ADD MEMBER [$upn] -- commented out because server roles are not supported on the target")
            }
        }
        $rdrrole.Close()
        
        # Walk through each database we are processing and look for uses of this login
        foreach ($database in $Databases)
        {
            # Get the user and default schema for the user in this database
            $cmd2.CommandText = ($SchemaQuery -f $database) + $name + "'"
            $rdrschema = $cmd2.ExecuteReader()
            if ($rdrschema.Read())
            {
                $dbusername = $rdrschema.GetString(0)
                if ($rdrschema.IsDBNull(1))
                {
                    $schema = "dbo"
                }
                else
                {
                    $schema = $rdrschema.GetString(1)
                }
                $rdrschema.Close()
            }
            else
            {
                $rdrschema.Close()
                Break   # not a user in this database
            }

            $dcmd.CommandText = ($DestUserQry -f $database) + $upn + "'"
            $exists = $dcmd.ExecuteScalar()
            
            # For MI target - we create a login at the server level (above) and a user in each target database
            if ($destversion -eq $SQLMI)
            {
                if ($exists -gt 0)
                {
                    $DropDBUsers += ,($database, ("DROP USER [$dbusername]"))
                }
                $CreateDBUsers += ,($database, ("CREATE USER [$upn] FOR LOGIN [$upn] WITH DEFAULT_SCHEMA=[$schema]"))
            }
            else # in Azure SQL DB/DW you can have SQL logins in master and linked users in the database, you with AAD accounts you can only create users at the database level (you can create an AAD user in master, but can't link it)
            {
                if ($type -eq 'S')
                {
                    if ($exists -gt 0)
                    {
                        $DropDBUsers += ,($database, ("DROP USER [$dbusername]"))
                    }
                    $CreateDBUsers += ,($database, ("CREATE USER [$name] FOR LOGIN [$name] WITH DEFAULT_SCHEMA=[$schema]")) 
                }
                else
                {
                    if ($exists -gt 0)
                    {
                        $CreateDBUsers += ,($database, ("-- CREATE USER [$upn] FROM EXTERNAL PROVIDER WITH DEFAULT_SCHEMA=[$schema] -- commented out because AAD user already exists on the target"))
                    }
                    else
                    {
                        $CreateDBUsers += ,($database, ("CREATE USER [$upn] FROM EXTERNAL PROVIDER WITH DEFAULT_SCHEMA=[$schema]"))
                    }
                }
            }

            # Process Database Roles for this database user
            $dbq = $DBUserRoleQry -f $database
            $cmd2.CommandText = $dbq + $name + "'"
            $rdrrole = $cmd2.ExecuteReader()
            while ($rdrrole.Read())
            {
                $DBRoleMember += ,($database, ("exec sp_addrolemember '" + $rdrrole.GetString(0) + "', [$upn]"))
            }
            $rdrrole.Close()

            # Process Object Level Permissions for this database user - note this only processes schema, table and column level permissions      
            $dbq = $PermQuery -f $database
            $cmd2.CommandText = $dbq + $name + "'"
            $rdrperm = $cmd2.ExecuteReader()
            while ($rdrperm.Read())
            {
                if ($rdrperm.GetString(0) -eq 'SCHEMA')
                {
                    $ObjectPerms += ,($database, ($rdrperm.GetString(4) + " " + $rdrperm.GetString(3) + " ON SCHEMA::[" + $rdrperm.GetString(1) + "] TO [$upn]"))
                }
                else
                {
                    $col = $rdrperm.GetString(2)
                    if ($col -eq ' ')
                    {
                        $ObjectPerms += ,($database, ($rdrperm.GetString(4) + " " + $rdrperm.GetString(3) + " ON " + $rdrperm.GetString(1) + " TO [$upn]"))
                    }
                    else
                    {
                        $ObjectPerms += ,($database, ($rdrperm.GetString(4) + " " + $rdrperm.GetString(3) + " ON " + $rdrperm.GetString(1) + "([$col]) TO [$upn]"))
                    }
                }
            }
            $rdrperm.Close()
        }
    }
}
$rdr.Close()

# Get custom Server roles
$ServerRoles = @()
$SrvRolePerms = @()
if ($ProdVersion -gt 10)  # SQL 2008 and SQL 2008 R2 did not have create server role support - so following query will fail
{
    $cmd.CommandText = $SrvRolesQry
    $rdr = $cmd.ExecuteReader()
    while ($rdr.Read())
    {
        $user = $rdr.GetString(1)
        if ($rdr.GetString(2) -ne 'S')  # for windows AD users or groups, do the AAD substitution
        {
            foreach($usr in $UserMap)
            {
                if ($usr[0] -eq $user)
                {
                    $user = $usr[1]
                    Break
                }
            }
        }
        if ($destversion -eq $SQLMI)
        {
            $dcmd.CommandText = $DestSrvRoleQry + $rdr.GetString(0) + "'"
            $exists = $dcmd.ExecuteScalar()
            if ($exists -gt 0)
            {
                $comment = " -- commented out because server role already exists on the target"
                $ServerRoles += ("-- CREATE SERVER ROLE [" + $rdr.GetString(0) + "] AUTHORIZATION [$user] $comment")
            }
            else
            {
                $comment = " -- this statement needs to be reviewed, since this permission may not be available on the target platform"
                $ServerRoles += ("CREATE SERVER ROLE [" + $rdr.GetString(0) + "] AUTHORIZATION [$user]")        
            }
        }
        else
        {
            $exists = 1
            $comment = " -- commented out because server roles are not supported on the target"
            $ServerRoles += ("-- CREATE SERVER ROLE [" + $rdr.GetString(0) + "] AUTHORIZATION [$user] $comment")
        }
        $cmd2.CommandText = $SrvRolePermQry + $rdr.GetString(0) + "'"
        $rdr2 = $cmd2.ExecuteReader()
        while ($rdr2.Read())
        {
            $prefix = ""
            if ($exists -gt 0)
            {
                $prefix = "-- "
            }
            $SrvRolePerms += ($prefix + $rdr2.GetString(0) + " " + $rdr2.GetString(1) + " TO [$user] $comment") 
        }
        $rdr2.Close()
    }
    $rdr.Close()

    # Process nested Custom Server Roles
    $cmd.CommandText = $NestedSrvRoleQry
    $rdr = $cmd.ExecuteReader()
    while ($rdr.Read())
    {
        if ($destversion -eq $SQLMI)
        {
            $ServerRoleMembers += "ALTER SERVER ROLE [" + $rdr.GetString(0) + "] ADD MEMBER [" + $rdr.GetString(1) + "]"
        }
        else
        {
            $ServerRoleMembers += "-- ALTER SERVER ROLE [" + $rdr.GetString(0) + "] ADD MEMBER [" + $rdr.GetString(1) + "] -- commented out because server roles are not supported on the target"
        }
    }
    $rdr.Close()
}

# Get custom Database roles for each database and build create role and permission statements
$DatabaseRoles = @(@())
$DBRolePerms = @(@())
foreach ($db in $Databases)
{
    $cmd.CommandText = ($DBRolesQry -f $db)
    $rdr = $cmd.ExecuteReader()
    while ($rdr.Read())
    {
        $role = $rdr.GetString(0)
        $user = $rdr.GetString(1)
        if ($rdr.GetString(2) -ne 'S')
        {
            foreach($usr in $UserMap)
            {
                if ($usr[0] -eq $user)
                {
                    $user = $usr[1]
                    Break
                }
            }
        }
        $dcmd.CommandText = ($DBRolesQryDest -f $db) + $role + "'"    # check destination database for role
        $exists = $dcmd.ExecuteScalar()
        if ($exists -gt 0)
        {
            $DatabaseRoles += ,($db, ("-- CREATE ROLE [$role] AUTHORIZATION [$user] -- commented out because role already exists on the target"))
        }
        else
        {
            $DatabaseRoles += ,($db, ("CREATE ROLE [$role] AUTHORIZATION [$user]"))
        }

        # Process Object Level Permissions for users - note this only processes schema, table and column level permissions      
        $dbq = ($PermQuery -f $db)
        $cmd2.CommandText =  $dbq + $role + "'"
        $rdrperm = $cmd2.ExecuteReader()
        while ($rdrperm.Read())
        {
            if ($rdrperm.GetString(0) -eq 'SCHEMA')
            {
                $DBRolePerms += ,($db, ($rdrperm.GetString(4) + " " + $rdrperm.GetString(3) + " ON SCHEMA::[" + $rdrperm.GetString(1) + "] TO [$role]"))
            }
            else
            {
                $col = $rdrperm.GetString(2)
                if ($col -eq ' ')
                {
                    $DBRolePerms += ,($db, ($rdrperm.GetString(4) + " " + $rdrperm.GetString(3) + " ON " + $rdrperm.GetString(1) + " TO [$role]"))
                }
                else
                {
                    $DBRolePerms += ,($db, ($rdrperm.GetString(4) + " " + $rdrperm.GetString(3) + " ON " + $rdrperm.GetString(1) + "([$col]) TO [$role]"))
                }
            }
        }
        $rdrperm.Close()
    }
    $rdr.Close()

    # Process nested Database Roles
    $cmd.CommandText = ($DBNestRolesQry -f $db)
    $rdr = $cmd.ExecuteReader()
    while ($rdr.Read())
    {
        $DBRoleMember += ,($db, ("exec sp_addrolemember '" + $rdr.GetString(0) + "', '" + $rdr.GetString(1) + "'"))   
    }
    $rdr.Close()
}

# Close Database Connections
$conn.Close()
$conn2.Close()
$dconn.Close()

# Processing complete - Output results (and possibly execute the statements on the target, if that option was set)
$date = Get-Date -UFormat "%Y/%m/%d"
$server = $SrcConStr.Substring(7, $SrcConStr.IndexOf(';')-7)
"-- Start of Logins/Users/Roles/Permissions Script - Generated: $date from Server: $server" 
"--"
"-- Please review this script carefully before applying, since permissions in SQL Server can be very complex and this script only processes a subset of the different combinations"
"--"

if ($CreateLogins.Length -gt 0)
{
    "-- Server Level Logins"
}

# Output each server level login - only SQL logins will work on DB/DW
foreach($login in $CreateLogins)
{
    $login
}

foreach ($database in $Databases)
{
    "--"
    "-- Database Level Commands for: $database"
    if ($destversion -eq $SQLMI)
    {
        "USE " + $database
    }

    "-- Database Users"

    # Drop Users in Database
    foreach ($drop in $DropDBUsers)
    {
        if ($drop[0] -eq $database)
        {
            $drop[1]
        }
    }

    # Create Users in Database
    foreach($create in $CreateDBUsers)
    {
        if ($create[0] -eq $database)
        {
            $create[1]
        }
    }

    "-- Database Roles"

    # Create Roles in Database
    foreach ($role in $DatabaseRoles)
    {
        if ($role[0] -eq $database)
        {
            $role[1]
        }
    }

    "-- Database Role Permissions"
    # Grant permissions to database roles
    foreach ($perm in $DBRolePerms)
    {
        if ($perm[0] -eq $database)
        {
            $perm[1]
        }
    }

    "-- Database Role Membership"

    # Add Users to Database Roles
    foreach($role in $DBRoleMember)
    {
        if ($role[0] -eq $database)
        {
            $role[1]
        }
    }

    "-- Database User Permissions"
    # Grant/Deny permissions at an object level
    foreach($perm in $ObjectPerms)
    {
        if ($perm[0] -eq $database)
        {
            $perm[1]
        }
    }
}

"--"
"-- Server Level Commands"
"--"
if ($destversion -eq $SQLMI)
{
    "-- Custom Server Roles - Note that some Server Roles are not available on Azure SQL MI, so the following statements need to be reviewed and adjusted as required."
}
else
{
    "-- Custom Server Roles - Note that Server Roles are not available on Azure SQL DB and DW, so the following statements need to be reviewed and adjusted, as required, to database roles"
}

if ($ServerRoles.Length -gt 0 -and $destversion -eq $SQLMI)
{
    "USE master"
}

foreach($role in $ServerRoles)
{
    $role
}

"-- Fixed and Custom Server Role Membership"

foreach($member in $ServerRoleMembers)
{
    $member
}

"-- Custom Server Role Permissions"
foreach($perm in $SrvRolePerms)
{
    $perm
}

"--"
"-- End of Script"