
# **3_ChangeSchemas (Python):** Change Sachems in APS MPP Scripts for APS to Azure SQLDW Code Migration 

## **How to Run the Program** ##


The program processing logic and information flow is illustrated in the diagram below: 
![Step 3: Change APS Schemas and Other Syntaxes for Code Migration](https://i.imgur.com/1zumanf.jpg)

Below are the steps to run the Python Program: 

**Step 1:** Create two configuration CSV files for the Program “CleanScripts.py”.  Refer the "Preparation Task: Two Configuration CSV Files Setup" after the steps for more details.  

**Step 2:** Run the CleanScripts.py and provide prompted info: The path and name(s) of the two configuration CSV files.


**Preparation Task: Two Configuration CSV Files Setup**

(1) Create the APS to Azure SQLDW Schema Mapping CSV file by referring the definitions below. Sample CSV configuration file is provided to aid this preparation task. 

| Parameter           | Purpose                              |      Value (Sample)     |
| --------------------| -------------------------------------|-------------------------| 
| ApsDbName   | Name of one APS Database                                               |    adventure_works,   stagedb |
| ApsSchema   | The Schema used by the APS Database                                    |    dbo, testSchema            |
| SQLDWSchema | The Schema name to be used by SQLDW corresponding to the   ApsSchema.  |  adw_dbo, adw_testScehma      |


(2) Specify the source and destination directories and object yype by referring the definitions below. Sample CSV file is provided to aid this preparation task. 


| Parameter           | Purpose                              |      Value (Sample)     |
| --------------------| -------------------------------------|-------------------------| 
| Active              | 1 – Run line, 0 – Skip line.         | 0 or 1                  |
| SicDir              | Directory where the APS Scripts resides. This should be the output file directories from Step 1: CreateMPPScripts. Must have “\” on end. | C:\APS2SQLDW\Output\1_CreateMPPScripts\adventure_works\Tables\ |
| OutDir        | Output director of this step, where the cleaned scripts will reside. Must have “\” on end. | C:\APS2SQLDW\Output\2_CleanScripts\adventure_works\Tables\        |
| ObjectType        | Type of the Scripts      | TABLE, VIEW, SP  (case insensitive)   |


## **What the Program(s) Does** ##

APS is an instance level service that supports multiple databases. Azure SQL DW is a database-level service that has one database per instance. In order for the Azure SQL DW to host all the original APS databases and the tables, the original APS schemas in various databases need to be changed to an appropriate (different) name. 

Below is a sample schema mapping matrix defined in a CSV file. This CSV file is used as the input to the "ChangeSchemas.py" program:

| ApsDbName       | ApsSchema  | SQLDWSchema    |
|-----------------|------------|----------------|
| adventure_works | dbo        | adw_dbo        |
| adventure_works | pb         | adw_pb         |
| adventure_works | testSchema | adw_testSchema |
| INFORMATICA1    | dbo        | IFMT_dbo       |
| stagedb         | dbo        | st_dbo         |

In addition to changing the schema names for Azure SQLDW database, the Python program performs other needed changes as well. Below table is a summary of what the Python program does, with "Before" and "After" examples. 

| # | Text (case insensitive)      (with or without “[ ]”) | Replace with             | Before (Example)                                                                               | After (Example)                                                                 |
|---|------------------------------------------------------|--------------------------|------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------|
| 1 | [APS_DB].[APS_Schema].[Table]                        | [SQLDW_Schema].[Table]   | Create/Delete Table [stagedb].[dbo].[Tmp_Dates]                                                | Create/Delete Table   [st_dbo].[Tmp_Dates]                                                  |
| 2 | [APS_Schema].[Table]                                 | [SQLDW_Schema].[Table]   | CREATE/Delete TABLE   [testSchema].[Tmp_Dates]                                                 | CREATE/Delete TABLE   [adw_testSchema].[Tmp_Dates]                                          |
| 3 | [APS_DB].sys. Or   APS_DB.sys.                       | .sys.                    | SELECT 1 FROM   adventure_works.sys.schemas                                                    | SELECT 1 FROM sys.schemas                                                                   |
| 4 | ‘[APS_DB_Name].[APS_Schema].[Table]’                 | ‘[SQLDW_Schema].[Table]' | IF   OBJECT_ID('[stagedb].[dbo].[Tmp_Dates]’)     IF OBJECT_ID(N'[stagedb].[dbo].[Tmp_Dates]’) | IF   OBJECT_ID('[st_dbo].[Tmp_Dates]’)     IF OBJECT_ID(N'[st_dbo].[Tmp_Dates]’)            |
| 5 | ‘[APS_Schema].[Table]’                               | ‘[SQLDW_Schema].[Table]' | IF   OBJECT_ID('[testSchema].[Tmp_Dates]’     IF OBJECT_ID(N'[testSchema].[Tmp_Dates]’) | IF   OBJECT_ID('[adw_testSchema].[Tmp_Dates      If OBJECT_ID(N'[testSchema].[Tmp_Dates]’)  |

 

