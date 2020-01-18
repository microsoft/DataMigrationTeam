			/***This Artifact belongs to the Data Migration Jumpstart Engineering Team***/
--
-- Netezza Inventory Script
-- Function, Aggregate and Library Inventory Report
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
-- Where 'dbname' is the name of the Netezza Database to inventory
-- The '-t' flag supresses column headers and is needed
-- 'NZInventory.sql' is the name of the input script
-- Run as linux user 'nz'
--
-- [nz@netezza ~]$ nzsql -dbname sales -f NZInventory.sql -o output.csv -t
--


--
-- Function Report
-- Columns: Database, Schema, 'FUNCTION', Function Name, Function Signature, Return Data Type, Is Deterministic, Is Fenced, API Version
--

select
	f.database || ',' ||
	f.schema || ',' ||
	'FUNCTION' || ',' ||
	f.function || ',' ||
	f.functionsignature || ',' ||
	f.returns || ',' ||
	f.deterministic || ',' ||
	f.fenced || ',' ||
	f.version
from
	admin._v_function as f
where
	database <> 'SYSTEM';
	
	
--
-- Aggregate Report
-- Columns: Database, Schema, 'AGGREGATE', Aggregate Name, Aggregate Signature, Return Data Type, Is Fenced, API Version
--

select
	a.database || ',' ||
	a.schema || ',' ||
	'AGGREGATE' || ',' ||
	a.aggregate || ',' ||
	a.aggregatesignature || ',' ||
	a.returns || ',' ||	
	a.fenced || ',' ||
	a.version
from
	admin._v_aggregate as a
where
	database <> 'SYSTEM';



--
-- Library Report
-- Columns: Schema, 'LIBRARY', Library Name, Library Dependencies, Is Automatic Load, Description
--

select
	l.schema || ',' ||
	'LIBRARY' || ',' ||
	l.library || ',' ||
	coalesce(l.dependencies, 'No Dependencies') || ',' ||
	l.automaticload || ',' ||
	coalesce(l.description, 'No Description')
from
	admin._v_library as l

select * from admin._v_library;

