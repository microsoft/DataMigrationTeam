-- Teradata Version Information
SELECT * FROM DBC.DBCInfo;

-- Total space - everything is owned by DBC
SELECT DatabaseName, PermSpace/1024.0/1024.0/1024.0 SpaceGB, CreateTimeStamp, LastAlterTimeStamp
FROM DBC.DatabasesV 
WHERE DatabaseName = 'DBC';

-- Database Sizes - current and maximum sizes and times
SELECT d.DatabaseName, PermSpace/1024.0/1024.0 SpaceMB, CreateTimeStamp, LastAlterTimeStamp, CurrentSizeGB, MaxSizeGB, PercentUsed
FROM DBC.DatabasesV d
	JOIN (SELECT  DatabaseName, SUM(CurrentPerm)/1024.0/1024.0/1024 CurrentSizeGB, SUM(MaxPerm)/1024.0/1024.0/1024 MaxSizeGB, cast(cast(SUM(CurrentPerm) as float)/NULLIFZERO(cast(SUM(MaxPerm) as float))*100 as int) PercentUsed 
			FROM DBC.DiskSpaceV
			GROUP BY DatabaseName) s on (d.DatabaseName = s.DatabaseName)
WHERE dbkind = 'D'
	  AND d.DatabaseName not in ('dbcmngr', 'LockLogShredder', 'SQLJ', 'SysAdmin', 'SYSBAR', 'SYSJDBC', 'SYSLIB', 'SYSSPATIAL', 'SystemFe', 'SYSUDTLIB', 'SYSUIF', 'Sys_Calendar', 'TDQCD', 'TDStats', 'tdwm', 'TD_SERVER_DB', 'TD_SYSFNLIB', 'TD_SYSGPL','TD_SYSXML')
ORDER BY d.DatabaseName;

-- Object Type Counts
SELECT DatabaseName,
		CASE TableKind
		when 'A' then 'Aggregate function'
		when 'B' then 'Combined aggregate and ordered analytical function'
		when 'C' then 'Table operator parser contract function'
		when 'D' then 'JAR'
		when 'E' then 'External stored procedure'
		when 'F' then 'Standard function'
		when 'G' then 'Trigger'
		when 'H' then 'Instance or constructor method'
		when 'I' then 'Join index' 
		when 'J' then 'Journal'
		when 'K' then 'Foreign server object'
		when 'L' then 'User-defined table operator'
		when 'M' then 'Macro'
		when 'N' then 'Hash index'
		when 'O' then 'Table with no primary index and no partitioning'
		when 'P' then 'Stored procedure'
		when 'Q' then 'Queue table'
		when 'R' then 'Table function'
		when 'S' then 'Ordered analytical function'		
		when 'T' then 'Table'
		when 'U' then 'User-defined data type'
		when 'V' then 'View'
		when 'W' then 'W?'
		when 'X' then 'Authorization' 
		when 'Y' then 'GLOP set'
		when 'Z' then 'UIF'
		when '1' then 'Dataset Schema Object'
		else TableKind || '?'
		END ObjectKind, COUNT(*) ObjectCount
FROM DBC.TablesV
WHERE DatabaseName NOT IN ('console', 'DBC', 'dbcmngr', 'LockLogShredder', 'SQLJ', 'SysAdmin', 'SYSBAR', 'SYSJDBC', 'SYSLIB', 'SYSSPATIAL', 'SystemFe', 'SYSUDTLIB', 'SYSUIF', 'Sys_Calendar', 'TDQCD', 'TDStats', 'tdwm', 'TD_SERVER_DB', 'TD_SYSFNLIB', 'TD_SYSGPL','TD_SYSXML')
GROUP BY DatabaseName, TableKind
ORDER BY 1;

-- Table level detail including temporal table types and partitioning information.
SELECT t.DatabaseName, t.TableName, PartitioningLevels, RowSizeFormat, TemporalProperty, CreateTimeStamp, LastAlterTimeStamp, SizeMB
FROM dbc.TablesV as t
		join (select DatabaseName, TableName, sum(CurrentPerm)/1024.0/1024.0 SizeMB from dbc.TableSize group by DatabaseName, TableName) s on (t.DatabaseName=s.DatabaseName and t.TableName=s.TableName)
WHERE tablekind in ('T', 'I', 'N', 'O') 
	AND t.DatabaseName NOT IN ('DBC', 'dbcmngr', 'LockLogShredder', 'SQLJ', 'SysAdmin', 'SYSBAR', 'SYSJDBC', 'SYSLIB', 'SYSSPATIAL', 'SystemFe', 'SYSUDTLIB', 'SYSUIF', 'Sys_Calendar', 'TDQCD', 'TDStats', 'tdwm', 'TD_SERVER_DB', 'TD_SYSFNLIB', 'TD_SYSGPL','TD_SYSXML')
ORDER BY 1, 2;

-- Count for potentially problematic column types
SELECT DatabaseName,
		sum(case when ColumnType = 'BO' then 1 else 0 end) ByteLargeObj,
		sum(case when ColumnType = 'CO' then 1 else 0 end) CharLargeObj,
		sum(case when ColumnType = 'A1' then 1 else 0 end) Array,
		sum(case when ColumnType = 'AN' then 1 else 0 end) MultiDimArray,
		sum(case when ColumnType = 'UT' then 1 else 0 end) UDT,
		sum(case when ColumnType in ('PD', 'PM', 'PS', 'PT', 'PZ') then 1 else 0 end) Period
FROM DBC.ColumnsV
WHERE DatabaseName NOT IN ('DBC', 'dbcmngr', 'LockLogShredder', 'SQLJ', 'SysAdmin', 'SYSBAR', 'SYSJDBC', 'SYSLIB', 'SYSSPATIAL', 'SystemFe', 'SYSUDTLIB', 'SYSUIF', 'Sys_Calendar', 'TDQCD', 'TDStats', 'tdwm', 'TD_SERVER_DB', 'TD_SYSFNLIB', 'TD_SYSGPL','TD_SYSXML')
GROUP BY DatabaseName
ORDER BY 1;

-- Join Index Information (Materialized Views)
SELECT *
FROM DBC.Indices
WHERE IndexType = 'J'
ORDER BY 1,2,3;
