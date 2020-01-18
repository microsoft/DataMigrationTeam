			/***This Artifact belongs to the Data Migration Jumpstart Engineering Team***/
--
-- Netezza Inventory Script
-- Object Inventory Overview
--
-- For Netezza
-- Script Version 1.0
--
-- Tested on Netezza 7.2
--
-- Created by:
--   Jonathon Frost (jfrost@microsoft.com)
--   Kuldeep Chauhan (kuldeep.chauhan@microsoft.com)
--   Mitch van Huuksloot (Mitch.van.Huuksloot@microsoft.com)
--
-- DIRECTIONS:
-- To run script, use the following command using the 'nzsql' command:
--
-- Where 'output.csv' is the name of the output file 
-- The '-t' flag supresses column headers and is needed
-- 'NZInventory.sql' is the name of the input script
-- Run as linux user 'nz' or other user with permissions
--
-- Syntax Example:
-- [nz@netezza ~]$ nzsql -f NZInventory.sql -o output.csv -t
--


select
	objdata.dbname || ',' ||
	objdata.owner || ',' ||
	objdata.objtype || ',' ||
	count(objdata.objtype)
from
	admin._v_sys_database as db
	left join
		admin._v_sys_object_data as objdata
		on db.objname = objdata.dbname
	left join
		admin._v_sys_object_storage_size as objsize
		on objdata.objid = objsize.tblid
group by
	objdata.dbname,
	objdata.owner,
	objdata.objtype
having
	objdata.objtype in ('TABLE', 'EXTERNAL TABLE', 'PROCEDURE', 'FUNCTION', 'AGGREGATE', 'LIBRARY', 'MATERIALIZED VIEW', 'MVIEW_STORE', 'SEQUENCE', 'VIEW', 'SYNONYM', 'CONSTRAINT')
	AND
	objdata.dbname not in ('SYSTEM')
order by
	objdata.dbname,
	objdata.owner,
	objdata.objtype;



