/***This Artifact belongs to the Data SQL Ninja Engineering Team***/
--
-- Netezza Inventory Script
-- Database and Table Sizes
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


-- 
-- Query to capture all user tables size on Netezza
--

select
	objdata.dbname || ',' ||
	sum(objsize.used_bytes) / 1024 / 1024 / 1024 / 1024 || ',' ||
	sum(objsize.used_bytes) / 1024 / 1024 / 1024  || ',' ||
	sum(objsize.used_bytes) / 1024 / 1024
from
	admin._v_sys_object_data as objdata,
	admin._v_sys_object_storage_size as objsize
where
	objdata.objid = objsize.tblid
group by
	objdata.dbname	
order by
	objdata.dbname,	
	sum(objsize.used_bytes) desc;



-- 
-- Query to capture all user tables size on Netezza
--

select
	objdata.dbname || ',' ||
	objdata.schema || ',' ||
	objdata.objname || ',' ||
	objdata.objtype || ',' ||
	sum(objsize.used_bytes) / 1024 / 1024 / 1024 / 1024 || ',' ||
	sum(objsize.used_bytes) / 1024 / 1024 / 1024 || ',' ||
	sum(objsize.used_bytes) / 1024 / 1024
from
	admin._v_sys_object_data as objdata,
	admin._v_sys_object_storage_size as objsize
where
	objdata.objid = objsize.tblid
group by
	objdata.dbname,
	objdata.schema,
	objdata.objname,
	objdata.objtype
order by
	objdata.dbname,
	objdata.schema,
	sum(objsize.used_bytes) desc;



