	/***This Artifact belongs to the Data SQL Ninja Engineering Team***/
--
-- Netezza Inventory Script
-- Procedure Inventory Report
--
-- For Netezza
-- Script Version 1.1
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
-- Procedure Report
-- Columns: Database, Schema, 'PROCEDURE', Procedure Name, Procedure Signature, Return Data Type, Number of Chars in Source Code
--

select

	p.database || '|' ||
	p.schema || '|' ||
	'PROCEDURE' || '|' ||
	p.procedure  || '|' ||
	p.proceduresignature || '|' ||
	p.returns  || '|' ||	
	length(p.proceduresource)	

from admin._v_procedure as p;