# APS to SQL DW Migration - Schema and Data Migration with PolyBase

## Contributors

**Arshad Ali**, Solution Architect

**Kalyan Yella**, Solution Architect 

**Vishal Singh**, Consultant

**Basawashree Vasmate**, Consultant

**NOTE** - We have tested these scripts on these two PDW versions, if you are running it on older version than these, you might have to make few changes to make it run there.

Microsoft SQL Server 2012 - 10.0.8015.0 (X64) Jul 5 2016 21:33:16 Copyright (c) Microsoft Corporation Parallel Data Warehouse (64-bit) on Windows NT 6.2 <X64> (Build 9200: )

Microsoft SQL Server 2012 - 10.0.7932.0 (X64) Mar 5 2016 03:17:30 Copyright (c) Microsoft Corporation Parallel Data Warehouse (64-bit) on Windows NT 6.2 <X64> (Build 9200: )

## 1. Introduction

This document talks about *Script Generation Automation Framework* which can help you
dynamically generate scripts for exporting table schema as well as data
from APS to blob storage and then to create corresponding tables and
import data back in SQL DW from the blob storage. The *Script Generation Automation
Framework* also generates scripts for other types of objects, like
views, stored procedures etc. The generated scripts then can be executed
sequentially or in parallel by running them in multiple query windows.

![figure1](https://user-images.githubusercontent.com/25438079/27752639-ead69ab2-5d96-11e7-86d4-566d3118a103.png)
Figure 1 - Schema and Data Migration Workflow

1.  Generate scripts (external table) for all tables in required source
    databases for the APS appliance.

2.  Generate scripts (external table) for all tables in SQL DW
    corresponding to the tables from source.

3.  Generate scripts (internal table) for all tables from required
    source databases for SQL DW, along with distribution, cluster
    indexing and partitioning information as they are defined in APS.

4.  Optionally, generate scripts for additional supporting objects for
    tables in APS, like additional non-clustered indexes, statistics,
    default constraints etc. if applicable.

5.  Generate scripts for modules (like views, stored procedures,
    functions etc.).

6.  You can then execute scripts, created in step 1, on APS appliance to
    create external tables in APS databases and exporting data out from
    appliance to configured blob storage (refer appendix section below
    to learn how about configuring blob storage in APS to use with
    external tables).

7.  Next, you can execute scripts, created in step 2, on SQL DW to
    created external tables in SQL DW and execute scripts, created in
    step 3, to create internal tables and load data into it (using CTAS
    from external tables). It also takes care of defining distribution,
    partitioning, indexes by deriving same structure from the APS
    databases.

8.  Then, you can execute scripts, created in step 4, on SQL DW to
    create like additional non-clustered indexes, statistics, default
    constraints etc. if applicable in SQL DW.

9.  Finally, you need to change (references of the table or view names
    in the code) and execute scripts, created in step 5, on SQL DW to
    create modules (like views, stored procedures, functions etc.) in
    SQL DW.

As cross database joins are not supported in SQL Data Warehouse,
databases from source are consolidated in to a single destination SQL
Data Warehouse and separated using schema. For example, for a source
database STG and schema DBO the corresponding schema in SQL Data
Warehouse will be STG\_DBO. Likewise, for a source database DM1 and
schema FINANCE the corresponding schema in SQL Data Warehouse will be
DM1\_FINANCE. Of course, this requires to changes references of the
objects in views or modules.

![figure2](https://user-images.githubusercontent.com/25438079/27752679-1c3ac858-5d97-11e7-97e8-e6176849829a.png)
Figure 2 - Schema Migration

For data migration, external tables are created in APS to export the
data out to blob storage and then external tables are created in SQL
Data Warehouse to reference the data from blob storage. Finally,
internal tables are created and populated with data from blob storage
via external tables in SQL Data Warehouse.

![figure3](https://user-images.githubusercontent.com/25438079/27752689-2afc4330-5d97-11e7-9920-b84aa00398d2.png)
Figure 3 - Data Migration with PolyBase

### 1.1 Feature Highlights

-   The framework lets you specify multiple databases to consider for
    migration. It dynamically scales to all the those specified
    databases and consider them iteratively in one go.

-   For internal tables in SQL DW, the framework derives partitioning
    strategy from APS for each of the tables and apply the same
    automatically for SQL DW internal tables.

-   For internal tables in SQL DW, the framework derives indexing
    strategy from APS for each of the tables and apply the same
    automatically for SQL DW internal tables.

    -   For clustered columnstore index when data load completes it
        creates clustered columnstore index on the SQL DW internal
        tables.

    -   For clustered rowstore index, if one exists on APS table, it
        applies the same to internal tables in SQL DW, by defining all
        columns in the same sequence and in same ascending\\descending
        order.

    -   If there are any non-clustered index (or indexes) on APS table,
        that also gets created for respective internal table in SQL DW
        automatically.

-   For internal tables in SQL DW, the framework derives statistics
    strategy from APS for each of the tables and apply the same
    automatically for respective table in SQL DW.

### 1.2 Sample script output – formatted for readability purpose

####  1.2.1 Create Data Source and File Format
Based on configuration parameter set, the framework generates data
source and file format (creating master key and credential is not shown
here):

		IF EXISTS (SELECT * FROM sys.external_file_formats WHERE name = 'ff_textdelimited')   
	        DROP EXTERNAL FILE FORMAT ff_textdelimited; 
            
		CREATE EXTERNAL FILE FORMAT ff_textdelimited  
		WITH (      
            FORMAT_TYPE = DELIMITEDTEXT,      
            FORMAT_OPTIONS (           
            FIELD_TERMINATOR = '^|^',          
            DATE_FORMAT = 'MM/dd/yyyy'),    
            DATA_COMPRESSION = 'org.apache.hadoop.io.compress.GzipCodec'  
		);
        
		IF EXISTS (SELECT * FROM sys.external_data_sources WHERE name = 'ds_blobstorage')      
	        DROP EXTERNAL DATA SOURCE ds_blobstorage;   
		CREATE EXTERNAL DATA SOURCE ds_blobstorage      
		WITH (           
            TYPE = HADOOP,          
            LOCATION = 'wasbs://container@blobaccount.blob.core.windows.net/'   
		);

####  1.2.2 Create Schema in APS for external tables
Based on configuration parameter set, framework creates a schema in APS
so that all the objects are segregated into for manageability purpose:

        USE AdventureWorksPDW2012; 
        IF EXISTS(SELECT * FROM sys.schemas WHERE name = 'EXTSQLDW')   
        	DROP SCHEMA [EXTSQLDW];   
        EXEC('CREATE SCHEMA [EXTSQLDW] AUTHORIZATION dbo;')
  
####  1.2.3 Create External Table - APS

This is just one sample script to create an external table in APS
database. Based on configurable parameters set, you can include or
exclude databases and tables, and framework takes into consideration of
only identified databases\\tables for migration. After execution of this
output script, you will have data for this table exported to specified
blob storage under folder specified.

        IF EXISTS(SELECT * FROM sys.external_tables WHERE name = 'dbo.FactInternetSales')            
        	DROP TABLE [EXTSQLDW].[dbo.FactInternetSales]; 
        
        CREATE EXTERNAL TABLE [EXTSQLDW].[dbo.FactInternetSales]     
        WITH (
        	LOCATION = '/AdventureWorksPDW2012/dbo/FactInternetSales/',      
        	DATA_SOURCE = ds_blobstorage,      
        	FILE_FORMAT = ff_textdelimited,      
        	REJECT_TYPE = VALUE,      
        	REJECT_VALUE = 0     
        	)     
        AS SELECT * FROM AdventureWorksPDW2012.[dbo].[FactInternetSales];

####  1.2.4 Create External Table – SQL DW

This is just one sample script to create an external table in SQL DW
database. As you can notice, the framework derives structure of the
table from table structure in APS database. Once this output script is
executed on SQL DW database, it will simply point to the data in blob
storage (no data is imported yet, data import happens with the next set
of scripts).

        IF NOT EXISTS(SELECT * FROM AdventureWorksPDW2012.sys.schemas WHERE name = 'AdventureWorksPDW2012_dbo')     
        	EXEC('CREATE SCHEMA [AdventureWorksPDW2012_dbo] AUTHORIZATION dbo;');
        
        IF EXISTS(SELECT * FROM sys.external_tables WHERE schema_id = SCHEMA_ID('AdventureWorksPDW2012_dbo') AND name = 'EXT_FactInternetSales')            
        	DROP TABLE [AdventureWorksPDW2012_dbo].[EXT_FactInternetSales];  
        
        CREATE EXTERNAL TABLE [AdventureWorksPDW2012_dbo].[EXT_FactInternetSales]    
        (
        	[ProductKey] int NOT NULL, 
        	[OrderDateKey] int NOT NULL, 
        	[DueDateKey] int NOT NULL, 
        	[ShipDateKey] int NOT NULL, 
        	[CustomerKey] int NOT NULL, 
        	[PromotionKey] int NOT NULL, 
        	[CurrencyKey] int NOT NULL, 
        	[SalesTerritoryKey] int NOT NULL, 
        	[SalesOrderNumber] nvarchar(20) COLLATE Latin1_General_100_CI_AS_KS_WS NOT NULL, 
        	[SalesOrderLineNumber] tinyint NOT NULL, 
        	[RevisionNumber] tinyint NOT NULL, 
        	[OrderQuantity] smallint NOT NULL, 
        	[UnitPrice] money NOT NULL, 
        	[ExtendedAmount] money NOT NULL, 
        	[UnitPriceDiscountPct] float NOT NULL, 
        	[DiscountAmount] float NOT NULL, 
        	[ProductStandardCost] money NOT NULL, 
        	[TotalProductCost] money NOT NULL, 
        	[SalesAmount] money NOT NULL, 
        	[TaxAmt] money NOT NULL, 
        	[Freight] money NOT NULL, 
        	[CarrierTrackingNumber] nvarchar(25) COLLATE Latin1_General_100_CI_AS_KS_WS NULL, 
        	[CustomerPONumber] nvarchar(25) COLLATE Latin1_General_100_CI_AS_KS_WS NULL    
        )
        WITH (
        	LOCATION = '/AdventureWorksPDW2012/dbo/FactInternetSales/',      
        	DATA_SOURCE = ds_blobstorage,      
        	FILE_FORMAT = ff_textdelimited,      
        	REJECT_TYPE = VALUE,      
        	REJECT_VALUE = 0     
        );

####  1.2.5 Create Internal Table – ROUND\_ROBIN

This is just one sample script to create an internal table in APS
database. As you can notice, the framework derives structure of the
table from table structure in APS database as well as it derives
distribution type, partitioning, index structure as well.

        CREATE TABLE [AdventureWorksPDW2012_dbo].[FactInternetSalesRR]    
        WITH (DISTRIBUTION = ROUND_ROBIN, 
        	PARTITION ([OrderDateKey] RANGE RIGHT FOR VALUES ([20000101], 
        	[20010101], [20020101], [20030101], [20040101], [20050101], 
        	[20060101], [20070101], [20080101], [20090101], [20100101], 
        	[20110101], [20120101], [20130101], [20140101], [20150101], 
        	[20160101], [20170101], [20180101], [20190101], [20200101], 
        	[20210101], [20220101], [20230101], [20240101], [20250101], 
        	[20260101], [20270101], [20280101], [20290101])) 
        )    
        AS    
        SELECT * FROM [AdventureWorksPDW2012_dbo].[EXT_FactInternetSalesRR];
        
        CREATE CLUSTERED COLUMNSTORE INDEX [cci_AdventureWorksPDW2012_dbo_FactInternetSalesRR] 
        ON [AdventureWorksPDW2012_dbo].[FactInternetSalesRR];

####  1.2.6 Create Internal Table – REPLICATED

As REPLICATED tables are yet not supported in SQL DW, the framework uses
ROUND\_ROBIN distribution for REPLICATED tables and put a comment inline
so that it can be identified and changed quickly once REPLICATED table
support is available in SQL DW.

        CREATE TABLE [AdventureWorksPDW2012_dbo].[FactInternetSalesR]    
        WITH (DISTRIBUTION = ROUND_ROBIN /*REPLICATE CHANGED TO ROUND_ROBIN*/, 
        	PARTITION ([OrderDateKey] RANGE RIGHT FOR VALUES ([20000101], [20010101], 
        	[20020101], [20030101], [20040101], [20050101], [20060101], [20070101], 
        	[20080101], [20090101], [20100101], [20110101], [20120101], [20130101], 
        	[20140101], [20150101], [20160101], [20170101], [20180101], [20190101], 
        	[20200101], [20210101], [20220101], [20230101], [20240101], [20250101], 
        	[20260101], [20270101], [20280101], [20290101])
        	) )    
        AS    
        SELECT * FROM [AdventureWorksPDW2012_dbo].[EXT_FactInternetSalesR];
        
        CREATE CLUSTERED COLUMNSTORE INDEX [cci_AdventureWorksPDW2012_dbo_FactInternetSalesR] 
        ON [AdventureWorksPDW2012_dbo].[FactInternetSalesR];

####  1.2.7 Create Internal Table – HASH

The framework derives distribution and hash key information from APS
databases and creates internal tables in SQL DW with the same structure.

        CREATE TABLE [AdventureWorksPDW2012_dbo].[FactInternetSales]    
        WITH (DISTRIBUTION = HASH([OrderDateKey]), PARTITION ([OrderDateKey] 
        	RANGE RIGHT FOR VALUES ([20000101], [20010101], [20020101], 
        	[20030101], [20040101], [20050101], [20060101], [20070101], 
        	[20080101], [20090101], [20100101], [20110101], [20120101], 
        	[20130101], [20140101], [20150101], [20160101], [20170101], 
        	[20180101], [20190101], [20200101], [20210101], [20220101], 
        	[20230101], [20240101], [20250101], [20260101], [20270101], 
        	[20280101], [20290101])) 
        )    
        AS    
        SELECT * FROM [AdventureWorksPDW2012_dbo].[EXT_FactInternetSales];
        
        CREATE CLUSTERED COLUMNSTORE INDEX [cci_AdventureWorksPDW2012_dbo_FactInternetSales] 
        ON [AdventureWorksPDW2012_dbo].[FactInternetSales];

####  1.2.8 Create Internal Table – CLUSTERED

Often tables in APS have clustered columnstore index but few small
tables might have clustered rowstore index, again the framework derive
this information from source and creates table accordingly in SQL DW.

        CREATE TABLE [AdventureWorksPDW2012_dbo].[DimSalesReason]    
        WITH (DISTRIBUTION = ROUND_ROBIN /*REPLICATE CHANGED TO ROUND_ROBIN*/ )    
        AS    
        SELECT * FROM [AdventureWorksPDW2012_dbo].[EXT_DimSalesReason];
        
        CREATE CLUSTERED INDEX [ci_AdventureWorksPDW2012_dbo_DimSalesReason] 
        ON [AdventureWorksPDW2012_dbo].[DimSalesReason] ([SalesReasonKey] ASC)


####  1.2.9 Create Statistics

By default, clustered columnstore index creates statistic on the table
though if there are additional user created statistics. This framework
identifies these additional statistics and create them once data load
SQL DW table has been loaded with data and index have been created.

        CREATE STATISTICS [OrderDatekey] ON [AdventureWorksPDW2012_dbo].[FactInternetSales] ([OrderDateKey]);
        CREATE STATISTICS [stat_FactInternetSalesReason_SalesOrderLineNumber] ON [AdventureWorksPDW2012_dbo].[FactInternetSalesReason] ([SalesOrderLineNumber]);
        CREATE STATISTICS [stat_FactInternetSalesReason_SalesOrderNumber] ON [AdventureWorksPDW2012_dbo].[FactInternetSalesReason] ([SalesOrderNumber]);
        CREATE STATISTICS [stat_FactInternetSalesReason_SalesReasonKey] ON [AdventureWorksPDW2012_dbo].[FactInternetSalesReason] ([SalesReasonKey]);

####  1.2.10 Create Modules

Currently, though, the framework can export scripts for all the modules
(views, stored procedures, functions) from APS, it cannot be directly
executed on SQL DW as is. It needs to be manually edited to change
references of the objects in the code, for example from 3-part naming to
2-part naming convention and then only it can be executed, or modules
can be created on SQL DW.

        CREATE PROC [dbo].[ETL_LogEvent] @SPName [VARCHAR](100),@StepName [VARCHAR](100) AS
        BEGIN
        
        DECLARE @ID INT,
                @EventDateTime Datetime
        
        SET @ID=(SELECT ISNULL(MAX(ID),0) FROM [dbo].[ETL_log])+1
        SET @EventDateTime=GETDATE()
        
        INSERT INTO [APS_ETL_Framework].[dbo].[ETL_log]([ID],[SPName],[StepName],[EventDateTime]) 
        VALUES(@ID,@SPName,@StepName,@EventDateTime)
        
        END;
        CREATE PROC [dbo].[ExecutionLogStart] @ExecutionID [VARCHAR](50),@SP [VARCHAR](100),@Section [VARCHAR](100),@Step [CHAR](5),@Message [VARCHAR](500),@Status [VARCHAR](16),@CreatedBy [INT] AS
        BEGIN
        
        DECLARE @CreatedOn DATETIME, 
                @Execution VARCHAR(50)
        
        SET @Execution=@ExecutionID+@Step
        
        SET @CreatedOn=GETDATE()
        
        INSERT INTO [dbo].[Log_SPExecution]
                    (
        			 [LogID],
        			 [ExecutionID],
        			 [StoredProc],
        			 [Section],
        			 [StartTime],
        			 [Message],
        			 [Status],
        			 [CreatedOn],
        			 [CreatedBy])
        VALUES      (
        			 @Execution,
        			 @ExecutionID,
        			 @SP,
        			 @Section,
        			 @CreatedOn,
        			 @Message,
        			 @Status,
        			 @CreatedOn,
        			 @CreatedBy
        	    ) 
        END
![figure4](https://user-images.githubusercontent.com/25438079/27752766-8f981a30-5d97-11e7-97d5-96a131ffaf3a.png)

## 2. Script Generation Automation Framework

### 2.1 Exporting Data from APS to Blob Storage

Script file available in attachment can be used for automatically
generating scripts for creating external tables in APS appliance and
exporting data to Azure Blob Storage. **ExportToBlob-Part1.dsql**
generates script for external tables but before execution you can specify a schema under which all these
external tables will be created.

	DECLARE @SchemaForExternalTable VARCHAR(255) = 'EXTSQLDW’

This allows you to specify databases to consider during migration. You
can specify one or more databases to consider in single execution. For
each database you want to include, you need to one INSERT statement for
each database as shown below:

	--step 2: define databases that you want to include
	INSERT INTO DatabasesToInclude VALUES ('AdventureWorksPDW2012')
  
After execution of the above script, output should look like this:

![figure4](https://user-images.githubusercontent.com/25438079/27752694-36884258-5d97-11e7-8138-43c9cde1bb22.png)
Figure 4 - Export - Dynamic Script Generation

Next you need to execute **ExportToBlob-Part2.dsql** but before that you
need to again specify few important configuration parameters, for
example,
 
	--step 1: define all parameters
	DECLARE @FormatType VARCHAR(100) = 'DELIMITEDTEXT'
	DECLARE @FieldDelimiter VARCHAR(10) = '^|^'
	DECLARE @DateFormat VARCHAR(12) = 'MM/dd/yyyy'
	DECLARE @DataCompression VARCHAR(100) = 'org.apache.hadoop.io.compress.GzipCodec'
	DECLARE @AzureStorageAccount VARCHAR(1000) = 'wasbs://<containername><accountname>.blob.core.windows.net/'
	
-   @AzureStorageAccount - You need to specify the blob storage location
    where data needs to be exported. This storage account must have been
    setup in core-site.xml file and APS must have been restarted after
    that change (refer appendix section below to learn how about
    configuring blob storage in APS to use with external tables).

-   @FieldDelimiter – You can specify a single character delimiter to
    have a compact data file but in case if you suspect a collision
    between one specific character delimiter with the data in tables,
    you can make it multi-characters.

Also, before execution of the **ExportToBlob-Part2.dsql** script you
need to copy script output (after executing **ExportToBlob-Part1.dsql**
script and as shown in Figure 2 above) to the end of the
**ExportToBlob-Part2.dsql** file.

This copied script has two types of script for each of the databases and
you need to execute it in this sequence (though its generated already in
proper order),

-   Execute first statement to switch database context and drop
    migration schema if already existing and create a new one.

-   Finally, run all the scripts for creating external tables and
    exporting data to blob storage for that database

![figure5](https://user-images.githubusercontent.com/25438079/27752710-477b4f24-5d97-11e7-916a-f8e5bdee7f24.png)
Figure 5 - Export - Script Execution Order

Note - You will need to manually clean up blob storage account before
you drop the external table and create it again or if you are executing
the script more than once.

Execute **ExportToBlob-Part3.dsql** for cleaning up objects from the APS
appliance, again you need to specify few configuration parameters, for
example by default this script only deletes external file format and
data source (assuming they are not in use); if you want to delete all
the external tables created earlier and their corresponding schema, you
need to set @DropExternalTableAndSchema to 1 before executing this
script.

        USE <AnyUserDatabase>;
        DECLARE @DropExternalTableAndSchema BIT = 0
        DECLARE @SchemaForExternalTable VARCHAR(255) = 'EXTSQLDW'

Please note, dropping external tables will not drop files created on
blob storage. If you want to delete data as well, you need to delete it
from the blob storage account manually.

### 2.2 Importing Data from Blob Storage to SQL DW

Script available in attachment can be used for automatically generating
scripts for creating external tables in SQL DW database. These external
tables must point to the same location where data was exported from APS,
in the earlier step.

You need to first execute **ImportFromBlob-Part1.dsql** on APS appliance
to generate script for external tables (external tables to be created in
SQL DW database). The output of the script should look like this (please
note, this script might take couple of minutes to hours depending on
number of databases, tables and columns, as it does lots of string
manipulation for dynamic SQL and string manipulation is slower in
APS\\SQL DW). The script generated here is in multiple parts copy all
the scripts (Part1-Part6). The script is broken down into multiple parts
due to limit of 8000 characters for varchar in APS and the table
definition could easily exceed that limit:

<img width="857" alt="figure6" src="https://user-images.githubusercontent.com/25438079/27752728-5e6ccae6-5d97-11e7-9222-6e108164f315.png">
Figure 6 - Import - External Tables

Again, the framework allows you to specify databases to work on. You can
specify one or more databases to consider in single execution. For each
database you want to include, you need to one INSERT statement for each
database, as shown below, in **ImportFromBlob-Part1.dsql** before
execution:

        INSERT INTO DatabasesToInclude VALUES ('AdventureWorksPDW2012')

Next you need to connect to SQL DW database and execute
**ImportFromBlob-Part2.dsql** script but before that you need to change
few important configuration parameters and copy scripts from above (as
shown in Figure 4) for executing it on SQL DW database:

-   @AzureStorageAccount - You need to specify the blob storage location
    where data was exported earlier. It should be exactly same as above.

-   @FieldDelimiter – You need to specify same character delimiter what
    you specified when exporting data. It should be exactly same as
    above.

        USE <SQL DW DatabaseName>
        --step 1: define all parameters
        DECLARE @FormatType VARCHAR(100) = 'DELIMITEDTEXT'
        DECLARE @FieldDelimiter VARCHAR(10) = '^|^'
        DECLARE @DateFormat VARCHAR(12) = 'MM/dd/yyyy'
        DECLARE @DataCompression VARCHAR(100) = 'org.apache.hadoop.io.compress.GzipCodec'
        DECLARE @AzureStorageAccount VARCHAR(1000) = 'wasbs://<containername><accountname>.blob.core.windows.net/'
        DECLARE @AzureStorageAccessKey VARCHAR(1000) = '******************************'

Next, you need to execute **ImportFromExternal-Part1.dsql** script. This
gives scripts for creating SQL DW internal tables and importing data
into them from external tables (example shown in section 1.2.5, 1.2.6,
1.2.7 and 1.2.8). You need to take result set and execute it into other
query window (you can split the result set and execute them in parallel
across multiple query windows).

### 2.3 Generating scripts for other objects

Finally, you can execute scripts (**GenerateModuleScript.dsql**,
**GenerateNonClusteredIndex.dsql** and
**GenerateUserCreatedStatistics.dsql**) for creating additional objects
like non-clustered indexes, statistics, modules etc.

Create the stored procedure from the script
CreateStatsForAllColumns.sql. To create statistics on all columns in the
table with this procedure, simply call the procedure.

## 3 References

<https://www.microsoft.com/en-us/sql-server/analytics-platform-system>

<https://docs.microsoft.com/en-us/azure/sql-data-warehouse/sql-data-warehouse-overview-what-is>

<https://blogs.msdn.microsoft.com/sqlcat/2017/05/17/azure-sql-data-warehouse-loading-patterns-and-strategies/>

<https://docs.microsoft.com/en-us/sql/relational-databases/polybase/polybase-guide>

## 4 Appendix

### 4.1 Configure PolyBase Connectivity to External Data
Before you can start exporting data out from APS appliance to Azure Blob
Storage account, there are some configuration changes need to be done
and appliance services need to be restarted. This link has details on
steps:
<https://msdn.microsoft.com/en-us/sql/analytics-platform-system/configure-polybase-connectivity-to-external-data>

<https://msdn.microsoft.com/en-us/sql/analytics-platform-system/use-a-dns-forwarder-to-resolve-non-appliance-dns-names>
