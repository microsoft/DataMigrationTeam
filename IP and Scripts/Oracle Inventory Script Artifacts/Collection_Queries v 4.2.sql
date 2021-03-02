/*
# Filename: Collection_Queries V4.2.sql
# Script purpose: Level 1 Assessment Script
# This script has been created to determine the usage of features in customer Oracle Database.
# It will give Microsoft necessary information about customer's Oracle database feature usage metrics for estimating migration effort to SQL Server.
#
# Authors: Microsoft 
# Comments: last updated- Feb 28, 2021
*/
set echo on
set colsep ,     
set pagesize 50000 
set heading on
set trimspool on 
set linesize 300 
spool "C:\output.txt"

/*Database Name*/
select GLOBAL_NAME as "DBName" from global_name;

/*Database Audit*/
SELECT COUNT(*) FROM dba_tables WHERE table_name IN ('AUD$', 'FGA_LOG$') ORDER BY 1;

/*Automated Maintenance Tasks*/ 
SELECT COUNT(*) FROM ALL_SCHEDULER_JOBS;

/*Database Email*/
SELECT COUNT(*) FROM ALL_SYNONYMS WHERE OWNER = 'PUBLIC' and table_name LIKE 'UTL_MAIL';

/*Collation*/
SELECT COUNT(*) from NLS_DATABASE_PARAMETERS WHERE parameter IN ( 'NLS_LANGUAGE', 'NLS_TERRITORY', 'NLS_CHARACTERSET', 'NLS_SORT');

/*Memory Usage*/
select value as "Count(*)" from v$pgastat where name='maximum PGA allocated';

/*Data Encryption*/
SELECT count(*) FROM dba_encrypted_columns;

 /*Global Temporary Table*/
select COUNT(*) from V$TEMP_SPACE_HEADER;

/*Table Partitioning*/
select COUNT(*) from v$option where parameter='Partitioning';

/*Stored Procedures*/
SELECT count (*) FROM ALL_OBJECTS WHERE OBJECT_TYPE IN ('PROCEDURE');

/*Views*/
select count(*) from sys.dba_views;

/*Indexing*/
select count(*) from dba_indexes;

/*Trace files*/
SELECT count(VALUE) as "Count(*)" FROM V$DIAG_INFO WHERE NAME = 'Default Trace File';

/*******************************/
/*Row-Level Security*/
SELECT CASE WHEN VALUE='FALSE' Then 0 ELSE 1 END "Count(*)" FROM V$OPTION WHERE PARAMETER = 'Oracle Label Security';

/*Database Logging*/
SELECT COUNT(*) FROM v$database;

/*Constraints*/
select count (*) from all_constraints where owner in ('select user from dual');

/*Datatypes*/
select COUNT(*) from all_tab_columns;

/*Oracle Components Installed*/
select COUNT(*) from dba_registry where     status = 'VALID';

/*Logins/User Accounts*/
SELECT count(*) FROM ALL_USERS;

/*Triggers*/
select count(*) from DBA_TRIGGERS;

/*Data Dictionary*/
SELECT count(*) from DICT;

/*Privileges*/

SELECT count(*) FROM DBA_SYS_PRIVS;

/*Access Control*/
SELECT count(*) FROM DBA_ROLES;

/*Tables*/
Select count (*) from dba_tables where owner in ('select user from dual');

/*Cluster*/
Select count(*) from DBA_CLUSTERS;

/*Column-level check constraint*/
SELECT count(*) FROM DBA_CONSTRAINTS where constraint_type='C';

/*Packages*/
SELECT count(*) FROM ALL_OBJECTS WHERE OBJECT_TYPE IN ('PACKAGE');

/*Synonyms*/
select count(*) from user_synonyms;
	
/*Sequences*/
Select count(*) from DBA_SEQUENCES; 

/*Snapshot*/
Select count (*) from DBA_HIST_SNAPSHOT;

/*Built-In Functions*/
select count(*) from  all_arguments where  package_name = 'STANDARD';

/*Change Data Capture*/
Select count (*) from ALL_CHANGE_TABLES;

/*Functions*/
SELECT count (*) FROM ALL_OBJECTS WHERE OBJECT_TYPE IN ('FUNCTION');
	
/*Linked Servers*/
select count (*) from DBA_DB_LINKS;

/*Processes and Threads*/
select COUNT(*) from V$THREAD;

/*Database Queue*/
SELECT count (*) FROM DBA_QUEUES ;

/*Instead Of Triggers*/
Select count (*) from DBA_TRIGGERS where Trigger_Type='INSTEAD OF';

/*Transparent Application Failover*/
select COUNT(*) FROM v$session WHERE  username not in ('SYS','SYSTEM','PERFSTAT') AND  failed_over = 'YES';	

/*Query planned outline*/
SELECT COUNT(*) FROM V$SQL;
 
/*Online index rebuilds*/ 
SELECT count(*) FROM DBA_INDEXES;

/*Export transportable tablespaces*/

Select count(*) from V$TRANSPORTABLE_PLATFORM;

/*Materialized Views*/
select count(*) from all_objects where OBJECT_TYPE='MATERIALIZED VIEW';
 
/*Bitmap indexes*/
SELECT count(*) FROM dba_indexes WHERE index_type IN ('BITMAP', 'FUNCTION-BASED BITMAP' );

/*Oracle parallel Query*/ 
SELECT count(*) FROM GV$SYSSTAT WHERE name LIKE 'Parallel operation%';

/*Oracle Streams*/
SELECT count(*) FROM ALL_OBJECTS WHERE OBJECT_TYPE IN ('FUNCTION','PROCEDURE','PACKAGE');

/*Function Based Index*/
select count(*) FROM dba_indexes WHERE index_type like 'FUNCTION-BASED%';
   
/*Tablespace point in time recovery (TSPITR)*/
 SELECT count(*) FROM SYS.TS_PITR_CHECK WHERE ('SYSTEM' IN (TS1_NAME, TS2_NAME) AND TS1_NAME <> TS2_NAME AND TS2_NAME <> '-1') OR (   TS1_NAME <> 'SYSTEM' AND TS2_NAME = '-1');

/*Parallel Buffers*/
SELECT count(*) FROM V$PX_PROCESS_SYSSTAT WHERE STATISTIC LIKE 'Buffers%';
 
/*Oracle DB Vault*/
SELECT COUNT(*) FROM V$OPTION WHERE PARAMETER = 'Oracle Database Vault';

/*Advanced Queue in use*/
SELECT COUNT(*) FROM dba_queue_tables;

/*Event Triggers enabled*/
SELECT COUNT(*) FROM sys.trigger$ a, sys.obj$ b WHERE a.sys_evts > 0 AND a.obj#=b.obj# AND baseobject IN (0, 88);

/*Supplemental Logging enabled*/
SELECT COUNT(*) FROM v$database WHERE SUPPLEMENTAL_LOG_DATA_MIN <> 'NO';

/*RAC clustering*/
SELECT COUNT(*) FROM v$active_instances;

/*Case Sensitive Password*/
SELECT CASE WHEN value='FALSE' THEN 0 ELSE 1 END "Count(*)" FROM gv$parameter WHERE (name LIKE '%sensitive%');

/*Block change tracking enabled*/
SELECT COUNT(*) FROM v$block_change_tracking;

/*Advanced Rewrite in use*/
SELECT COUNT(*) FROM dba_rewrite_equivalences;

/*Data Guard Replication enabled*/
SELECT COUNT(*) FROM DBA_FEATURE_USAGE_STATISTICS WHERE NAME = 'Data Guard';

/*Roles*/
SELECT count(*) FROM DBA_ROLE_PRIVS;

/*
Feature id	118
Feature Name:	Oracle Resource Manager
Description: Viewing the Currently Active Plans

REMOVED Statements
*/

/*
Feature id	127
Feature Name:	Automated SQL Tuning
Description:

REMOVED Statements
*/

spool off;
exit;

