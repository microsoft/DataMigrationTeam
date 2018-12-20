--
-- Teradata Inventory Script
-- Database and Table Sizes
--
-- For Teradata
-- Script Version 1.0
--
--
-- Created by:
--   Celia Muriel (celia.muriel@microsoft.com)
--
-- DIRECTIONS:
--
-- Please output it xls, one excel per query
--
--


-- 
-- Database and tables with size
--
locking row for access nowait
select  rank (CurrentPerm_MB asc) as SpaceRank
                                         , DatabaseName
                                         , TableName
                                         , CurrentPerm_MB
                                         , PeakPerm
                                         , SkewFactor
from
(
                           select  DatabaseName
                                                                     , TableName
                                                                     , sum (CurrentPerm) / (1024 * 1024) as CurrentPerm_MB
                                                                     , sum (PeakPerm) as PeakPerm
                                                                     , (100 - (avg (CurrentPerm) / nullifzero (max (CurrentPerm)) * 100)) as SkewFactor
                           from      DBC.TableSize
                           group by 1, 2
) as A
order     by 1;



-- 
-- Index detail
--
locking row for access nowait
select  I.DatabaseName
                                         , I.TableName
                                         , I.IndexNumber
                                         , I.IndexType
                                         , I.IndexName
                                         , I.ColumnName
                                         , I.CreatorName
                                         , I.CreateTimeStamp
                                         , I.LastAlterName
                                         , I.LastAlterTimeStamp
                                         , I.AccessCount
                                         , I.LastAccessTimeStamp
from DBC.Indices as I
order by 1, 2, 3;

-- 
-- Query to capture Tables
--
locking row for access nowait
select  T.DatabaseName
      , T.TableName
      , T.Version
      , T.TableKind
      , T.JournalFlag
      , T.CreatorName
      , T.LastAlterName
      , T.LastAlterTimeStamp
      , T.AccessCount
      , T.LastAccessTimeStamp
from DBC.Tables as T
where T.ProtectionType = 'F'
order by 1, 2;


-- 
-- Database detail
--
locking row for access nowait
select  D.DatabaseName
      , D.CreatorName
      , D.OwnerName
      , D.AccountName
      , D.JournalFlag
      , D.PermSpace / (1024 * 1024) as PermSpace_MB
      , D.SpoolSpace / (1024 * 1024) as SpoolSpace_MB
      , D.TempSpace / (1024 * 1024) as TempSpace_MB
      , D.CreateTimeStamp
      , D.LastAlterName
      , D.LastAlterTimeStamp
      , D.DBKind
      , D.AccessCount
      , D.LastAccessTimeStamp
from DBC.Databases as D
where D.ProtectionType = 'F'
order by 1;

-- 
-- Column detail
--
locking row for access nowait
select  DatabaseName
                                         , TableName
                                         , ColumnName
                                         , ColumnType
                                         , ColumnLength
                                         , Nullable
                                         , DecimalTotalDigits
                                         , DecimalFractionalDigits
                                         , UpperCaseFlag
                                         , ColumnConstraint
                                         , CreatorName
                                         , CreateTimeStamp
                                         , LastAlterName
                                         , LastAlterTimeStamp
                                         , AccessCount
                                         , LastAccessTimeStamp
                                         , CompressValueList
from DBC.Columns
where Compressible = 'C'
and   CompressValue is not null
order by 1, 2, 3;

-- 
-- Object count
--

select   trim (T.DatabaseName)
              , case
                  when T.TableKind = 'A' then 'Aggregate function'
          when T.TableKind = 'B' then 'Combined aggregate and ordered analytical function'
          when T.TableKind = 'C' then 'Table operator parser contract function'
          when T.TableKind = 'D' then 'JAR'
          when T.TableKind = 'E' then 'External stored procedure'
          when T.TableKind = 'F' then 'Standard function'
          when T.TableKind = 'G' then 'Trigger'
          when T.TableKind = 'H' then 'Instance or constructor method'
          when T.TableKind = 'I' then 'Join index'
          when T.TableKind = 'J' then 'Journal'
          when T.TableKind = 'K' then 'Foreign server object'
          when T.TableKind = 'L' then 'User-defined table operator'
          when T.TableKind = 'M' then 'Macro'
          when T.TableKind = 'N' then 'Hash index'
          when T.TableKind = 'O' then 'Table with no primary index and no partitioning'
          when T.TableKind = 'P' then 'Stored procedure'
          when T.TableKind = 'Q' then 'Queue table'
          when T.TableKind = 'R' then 'Table function'
          when T.TableKind = 'S' then 'Ordered analytical function'
          when T.TableKind = 'T' then 'Table'
          when T.TableKind = 'U' then 'User-defined type'
          when T.TableKind = 'V' then 'View'
          when T.TableKind = 'X' then 'Authorization'
          when T.TableKind = 'Y' then 'GLOP set'
          when T.TableKind = 'Z' then 'UIF'
          when T.TableKind = '1' then 'A DATASET schema object created by CREATE SCHEMA'
                          else 'Unknown'
                end as TypeOfObject
              , count (*)
from    DBC.Tables as T
where upper (T.DatabaseName) <> 'DBC'
order by 1, 2;

