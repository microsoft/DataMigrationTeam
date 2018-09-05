
# **5_CreateExternalTablesSQLDW (PowerShell):** Generate "Create External Table" DDLs for Azure SQLDW 
## **How to Run the Program** ##

The program processing logic and information flow is illustrated in the diagram below: 
![Step 5: Generate T-SQL Scripts for Azure SQLDW External Table Creation DDLs](https://i.imgur.com/hpmn0Zg.jpg)


Below are the steps to run the PowerShell Program(s): 

**Step 1:** Create the configuration driver CSV file for the Python Program.  Refer the "Preparation Task: Configuration Driver CSV File Setup" after the steps for more details.  

**Step 2:** Run the script ScriptCreateExternalTableDriver.ps1. Provide the prompted information: The path and name of the Configuration Driver CSV File. The script does not connect to the APS or SQLDW.  The only input for this script is the config.csv file. 


**Preparation Task: Configuration Driver CSV Files Setup**

Create the Configuration Driver CSV File based on the definition below. Sample CSV configuration file is provided to aid this preparation task. 

There is also a Job-Aid PowerShell program called "**Generate_Step5_ConfigFiles.ps1**" which can help you to generate an initial configuration file for this step. This Generate_Step5_ConfigFiles.ps1 uses a driver configuration SCV file named "ConfigFileDriver.csv" which has instructions inside for each parameter to be set. 


| Parameter        | Purpose                                                                                        | Value   (Sample)          |
|------------------|------------------------------------------------------------------------------------------------|---------------------------|
| Active           | 1 – Run line, 0 – Skip line                                                                    | 0 or 1                    |
| OutputFolderPath | Name of the path to output the resulte to                                                      | C:\Temp\NewDDL\ExportAPS\ |
| FileName         | Name of the output file                                                                        | DimCustomer               |
| InputFolderPath  | Path to the create Table output from step 2                                                    | C:\Temp\NewDDL\           |
| InputFileName    | Name of the Create Table script                                                                | DimCustomer.dsql          |
| SchemaName       | Name of the schema to create the external table in                                             | Dbo                       |
| ObjectName       | Name of the external table to create                                                           | Ext_dimCustomer           |
| DateSource       | Name of the data source to use for the external table                                          | Export_BlobStorage        |
| FileFormat       | Name of the File Format to use when exporting the data. Must   already be created              | DelimitedNoDateZip        |
| FileLocation     | Path to the export the data to on blobstorage.  Each Table should have its own file   location | /APS_Export/DimCustomer/  |

If the FileLocation has the “{@Var}”, the PowerShell scripts will generate create external table having a configurable location. See sample T-SQL Statement generated below. 

This configurable variable {@Var} can be replaced with a value such as: 

**test** – to import data to a location to hold test data

**dev** – to import data to a locate to hold dev data

**prod** – to import data to a location to hold prod data. 

Sample Generated File: ext_adw_dbo_DimAccount_DDL.dsql 

    CREATE EXTERNAL TABLE [ext_adw_dbo].[ext_DimAccount]
    (
    	[AccountKey]	int	NOT NULL 
    	,[ParentAccountKey]	int	NULL 
    	,[AccountCodeAlternateKey]	int	NULL 
    	,[ParentAccountCodeAlternateKey]	int NULL 
    	,[AccountDescription]	nvarchar	(50)	
    	,[AccountType]	nvarchar	(50)		,[Operator]	nvarchar	(50)	COLLATE	
    	,[CustomMembers]	nvarchar	(300)		,[ValueType]	nvarchar	(50)	COLLATE	
    	,[CustomMemberOptions]	nvarchar	(200)	
    )
     WITH (  
    LOCATION='/{@Var}/adw/dbo_DimAccount',  
    DATA_SOURCE = AzureBlobDS,  
    FILE_FORMAT = DelimitedNoDateZIP)
    
## **What the Program(s) Does** ##

After the data has been exported from APS, the data now needs to be inserted into SQLDW.  Before this can occur, the external table needs to be created on Azure SQLDW.  This is completed by using the create table statements and converting the statement into an external table. This PowerShell program(s) generate these "Create External Table" Statements. 


Sample generated T-SQL scripts for External Table Creation in Azure SQLDW:  

    CREATE EXTERNAL TABLE [ext_adw_dbo].[ext_FactFinance]
    (
    	[FinanceKey]	int	NOT NULL 
    	,[DateKey]	int	NOT NULL 
    	,[OrganizationKey]	int	NOT NULL 
    	,[DepartmentGroupKey]	int	NOT NULL 
    	,[ScenarioKey]	int	NOT NULL 
    	,[AccountKey]	int	NOT NULL 
    	,[Amount]	float	(53)	NOT NULL 
    )
    WITH (  
    LOCATION='/prod/adventure_works/dbo_FactFinance',  
    DATA_SOURCE = AzureBlobDS,  
    FILE_FORMAT = DelimitedNoDateZIP)
    
