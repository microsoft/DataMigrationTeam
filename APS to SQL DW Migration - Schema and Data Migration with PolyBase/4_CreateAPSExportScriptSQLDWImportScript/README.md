
# **4_CreateExportImportStatements (PowerShell):** Generate the export and import statements necessary to move the data from APS to Azure SQLDW

## **How to Run the Program** ##

The program processing logic and information flow is illustrated in the diagram below: 
![Step 4: Generate T-SQL Scripts for Exporting APS Data and Importing Into Azure SQLDW](https://i.imgur.com/ifrYS48.jpg)

Below are the steps to run the PowerShell Program(s): 

**Step 1:** Create the configuration driver CSV file for the Python Program.  Refer the "Preparation Task: Configuration Driver CSV File Setup" after the steps for more details.  

**Step 2:** Run the script ScriptCreateExportImportStatementDriver.ps1. Provide the prompted information: The path and name of the Configuration Driver CSV File. The script does not connect to the APS or SQLDW.  The only input for this script is the config.csv file. 


**Preparation Task: Configuration Driver CSV Files Setup**

Create the Configuration Driver CSV File based on the definition below. Sample CSV configuration file is provided to aid this preparation task. 

There is also a Job-Aid PowerShell program called "**Generate_Step4_ConfigFiles.ps1**" which can help you to generate an initial configuration file for this step. This Generate_Step4_ConfigFiles.ps1 uses a driver configuration SCV file named "ConfigFileDriver.csv" which has instructions inside for each parameter to be set. 


| Parameter        | Purpose                                                                                        | Value   (Sample)                                                       |
|------------------|------------------------------------------------------------------------------------------------|------------------------------------------------------------------------|
| Active           | 1 – Run line, 0 – Skip line                                                                    | 0 or 1                                                                 |
| DatabaseName     | Name of the database in APS                                                                    | AdventureWorks                                                         |
| OutputFolderPath | Name of the path to output the resulte to                                                      | C:\Temp\NewDDL\ExportAPS\                                              |
| FileName         | Name of the output file                                                                        | DimCustomer                                                            |
| SourceSchemaName | Name of the APS/Source Schema                                                                  | Dbo                                                                    |
| SourceObjectName | Name of the source object to work with                                                         | DimCustomer                                                            |
| DestSchemaName   | Name of the destination schema on SQLDW                                                        | Dbo                                                                    |
| DestObjectName   | Name of the destination object                                                                 | DimCustomer                                                            |
| DataSource       | Name of the data source to use.    This must already be created                                | Export_BlobStorage                                                     |
| FileFormat       | Name of the File Format to use when exporting the data. Must   already be created              | DelimitedNoDateZip                                                     |
| ExportLocation   | Path to the export the data to on blobstorage.  Each Table should have its own file   location | /APS_Export/adw/dbo-DimCustomer/ or   /APS_Export/stdb/dbo-DimCustomer |
| InsertFilePath   | Path to write the import statements                                                            | C:\Import\SQLDWScripts\                                                |
| ImportSchema     | Name of the new schema on SQLDW                                                                | dbo                                                                    |


## **What the Program(s) Does** ##

The PowerShell Program generates the T-SQL Scripts to export APS data into Azure Blob Storage. It also generates the T-SQL Scripts to import exported data from Azure Blob Storage into Azure SQLDW. 

The program generates the right structure, with the specified table, specified external data source name, the specified file format, and the specified location in Azure Blob Storage to store the data. All the specifications are set in the configuration driver CSV file. 

Below are example of the T-SQL Scripts for one single table.

Sample generated T-SQL scripts to export APS Table into Azure Blob Storage:  
     
    Create External Table adventure_works.ext_adw_dbo.ext_FactFinance
    WITH (
    	LOCATION='/prod/adventure_works/dbo_FactFinance',
    	DATA_SOURCE = AzureBlobDS,
    	FILE_FORMAT = DelimitedNoDateZIP
    	)
    AS 
    SELECT * FROM adventure_works.dbo.FactFinance
    Option(Label = 'Export_Table_adventure_works.dbo.FactFinance')

Sample generated T-SQL scripts to import data into Azure Blob Storage:

     INSERT INTO adw_dbo.FactFinance
      SELECT * FROM ext_adw_dbo.ext_FactFinance
    	Option(Label = 'Import_Table_adw_dbo.FactFinance')


    
    
