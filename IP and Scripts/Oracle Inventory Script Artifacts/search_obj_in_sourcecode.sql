--Created by Bram Pahlawanto
--Initial Version 22-May-2018
--$Id: search_obj_in_sourcecode.sql 277 2020-04-30 00:48:02Z bpahlawa $
--$Date: 2020-04-30 10:48:02 +1000 (Thu, 30 Apr 2020) $
--$Author: bpahlawa $
--$Rev: 277 $

set lines 200 pages 50000 verify off
set serveroutput on size 1000000
col name format a40
col line format 99999
col text format a101
select name,line,substr(text,1,100) text
from
(
select owner ||'.'|| name name,line,trim(text) text from dba_source
where regexp_substr(owner,'(' || replace('&&SCHEMANAME',',','|') || ')') is not null
and regexp_substr(TEXT,'(' || replace(lower('&&SEARCHOBJECT'),',','.*\(|') || '.*\(|' || replace(upper('&&SEARCHOBJECT'),',','.*\(|') || '.*\()',1,1) is not null
MINUS
select owner||'.'||name name,line,trim(text) text from dba_source
where regexp_substr(owner,'(' || replace('&&SCHEMANAME',',','|') || ')') is not null
and regexp_substr(TEXT,decode('&&EXCLUDEOBJECT','',null,'('||replace(lower('&&EXCLUDEOBJECT'),',','.*\(|') || '.*\(|' || replace(upper('&&EXCLUDEOBJECT'),',','.*\(|') || '.*\()'),1,1) is not null
MINUS
select owner||'.'|| name name,line,trim(text) text from dba_source
where regexp_substr(owner,'(' || replace('&&SCHEMANAME',',','|') || ')') is not null
and regexp_substr(TEXT,'--.*',1,1) is not null
)
order by 1,2
/
