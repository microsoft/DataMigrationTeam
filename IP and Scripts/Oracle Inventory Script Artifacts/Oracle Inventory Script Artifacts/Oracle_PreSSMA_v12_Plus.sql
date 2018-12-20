REM FUNCTION:   List the count of objects for each object type under each non-system schema
REM REQUIRES:   v$instance, sys.all_objects
REM

SET newpage 0;
SET pagesize 50000 ;
SET echo OFF ;
SET feedback OFF ;
SET verify OFF ;
SET markup html OFF;
SET linesize 250 ;
--
--
-- this is the output file that will capture the data use this first, then comment and uncommend second line for subsequent use
SPOOL D:\Data\PreSSMAOutput.csv REPLACE
 --SPOOL D:\Data\PreSSMAOutput.csv APPEND
set termout off
SET HEADING OFF

SELECT host_name     || ',' || 
       instance_name || ',' ||  
	   version       || ',' || 
	   owner         || ',' ||   
	   object_type   || ',' ||  
	   B.status      || ',' ||  
	   COUNT(object_id) "Svr,Inst,Ver,Sch,ObTyp,Stat,Ct"
FROM v$instance a, sys.all_objects b
WHERE owner NOT IN ('OWBSYS_AUDIT',   'MDSYS', 'PUBLIC',  'OUTLN',  'CTXSYS',   'OLAPSYS',                                                                                                                                                                                                                                                     
  'FLOWS_FILES',  'OWBSYS',  'SYSTEM', 'HR',  'ORACLE_OCM',    'EXFSYS',                                                                                                                                                                                                                                                 
  'SCOTT', 'SH', 'PM',   'DBSNMP',    'ORDSYS',  'ORDPLUGINS',  'SYSMAN',  'OE',  'IX',                                                                                                                                                                                                                                                         
  'APPQOSSYS',    'XDB',   'ORDDATA',    'BI', 'SYS',  'WMSYS', 'SI_INFORMTN_SCHEMA'  ) 
AND owner NOT LIKE 'APEX_%' 
GROUP BY   host_name, instance_name, version, owner, object_type, b.status 
ORDER BY owner, object_type, b.status ;

SELECT host_name     || ',' || 
       instance_name || ',' ||     
       version       || ',' || 
       C.owner       || ',Raw Data (Mb),VALID,'   || 
       Round( sum(avg_row_len*num_rows)*0.000001,2) "Svr,Inst,Ver,Sch,ObTyp,Stat,Ct"
FROM v$instance a, 
 dba_tables C
WHERE owner NOT IN ('OWBSYS_AUDIT',   'MDSYS', 'PUBLIC',  'OUTLN',  'CTXSYS',   'OLAPSYS',                                                                                                                                                                                                                                                     
  'FLOWS_FILES',  'OWBSYS',  'SYSTEM', 'HR',  'ORACLE_OCM',    'EXFSYS',                                                                                                                                                                                                                                                 
  'SCOTT', 'SH', 'PM',   'DBSNMP',    'ORDSYS',  'ORDPLUGINS',  'SYSMAN',  'OE',  'IX',                                                                                                                                                                                                                                                         
  'APPQOSSYS',    'XDB',   'ORDDATA',    'BI', 'SYS',  'WMSYS', 'SI_INFORMTN_SCHEMA'  ) 
AND owner NOT LIKE 'APEX_%' 
GROUP BY   host_name, instance_name, version, c.owner 
ORDER BY owner 
;


SELECT host_name     || ',' || 
       instance_name || ',' ||     
       version       || ',' || 
       C.owner       || '.' ||
	   c.table_name  || ',Table Sizing,'   || 
       avg_row_len   || ','   || 
       avg_row_len*num_rows  "Svr,Inst,Ver,Sch,ObTyp,Stat,Ct"
FROM v$instance a, 
 dba_tables C
WHERE owner NOT IN ('OWBSYS_AUDIT',   'MDSYS', 'PUBLIC',  'OUTLN',  'CTXSYS',   'OLAPSYS',                                                                                                                                                                                                                                                     
  'FLOWS_FILES',  'OWBSYS',  'SYSTEM', 'HR',  'ORACLE_OCM',    'EXFSYS',                                                                                                                                                                                                                                                 
  'SCOTT', 'SH', 'PM',   'DBSNMP',    'ORDSYS',  'ORDPLUGINS',  'SYSMAN',  'OE',  'IX',                                                                                                                                                                                                                                                         
  'APPQOSSYS',    'XDB',   'ORDDATA',    'BI', 'SYS',  'WMSYS', 'SI_INFORMTN_SCHEMA'  ) 
AND owner NOT LIKE 'APEX_%' and Avg_Row_Len > 0
ORDER BY owner 
;

set termout on
SPOOL OFF