
# Process and Tools for APS Pre-Assessment, Migration Scoping, and APS to Azure SQLDW Code and Data Migration 


## The APS Pre-Assessment and Migration Scoping Tools 

The Pre-Assessment Tool (PowerShell) is designed to gather APS object meta data (schema, object type, object count, space used by object, etc.), table meta data (table name, distribution type, distribution column, storage type, number of rows, row key, etc). The information gathered is stored in organized CSV output files. 

The results of the Pre-Assessment Tool can then be summarized by the Scoping Tool (PowerShell). The results of the scoping tool is written into an Excel file. This excel file has pivot tables that provide succinct object meta data summarized and organized by databases. The summary information can be used to assist customers to estimate the migration effort. 

The tools and documentation for the tools can be found by the link below: 

**0. [Pre-AssessmentAndMigrationScoping](http://www.microsoft.com "Step 0: APS Pre-Assessment and Migration Scoping") (PowerShell)**: Gather APS meta data and analyze the results to aid scoping migration effort.


## The Six-Step Migration Process

The next six sub-folder (directory) contains the scripts and documentation for the 6-step APS to Azure SQLDW data migration process. 

The six-step migration process is illustrated in the diagram below. Step 1, 4, 5, and 6 are written in PowerShell while step 2 and 3 are written in Python. 


![6-Step Migration Process](https://i.imgur.com/X7jnK80.jpg)


As illustrated in the above diagram, the output of the step 1 is used as input to the step 2. The output of the step 2 is used as input to Step 3. The output of the step 3 is used as input to Step 4, 5, and subsequently, step 6. In each of the steps 1-5, T-SQL Scripts are generated as output files based on designed processing logic. The Output T-SQL Scripts of the step 3, step 4, and step 5 are used as input to step 6, which is to deploy T-SQL DDLs into Azure SQLDW (Tables, Views, Stored Procedures, External Tables), and then run APS Export and SQLDW Import scripts, respectively. 

The PowerShell or Python Scripts along with the documentations can be found by clicking the following links:


The tools and documentation for each step of the process is stored in the following sub-directories: 

**1. [CreateMPPScripts](http://www.microsoft.com "Step 1: Create MPP Scripts") (PowerShell)**: Create MPP T-SQL scripts from APS.

**2. [CleanScripts](http://www.microsoft.com "Step 2: Clean Up MPP Scripts") (Python)**: Clean up output T-SQL scripts from Step 1.

**3. [ChangeSchemas](http://www.microsoft.com "Step 3: Change Schemas of the APS Scripts") (Python)**: Make Schema changes to MPP DDL Scripts. 

**4. [CreateAPSExportScriptSQLDWImportScripts](http://www.microsoft.com "Step 4: Create T-SQL Scripts to Export APS Data and Import Data Into Azure SQLDW ") (PowerShell)**: Create Data Export/Import Scripts.

**5. [CreateExternalTablesSQLDW](http://www.mocrosoft.com "Step 5: Generate T-SQL Scripts to Create Azure SQLDW External Tables") (PowerShell)**:  Create External Tables for SQLDW. 

**6. [DeployScriptsToSQLDW](http://www.microsoft.com "Step 6: Deploy (Run) T-SQL Scripts Specified in Configuration File") (PowerShell)**: Run Scripts for Migration.

* Export APS Data to Azure – Run T-SQL Scripts from output generated in step 4 above
* Create Tables/Views/SPs – Run T-SQL Scripts from output generated in step 3 above (SP’s require manual changes first or afterwards)
* Import Data into Azure SQLDW – Run T-SQL Scripts from output generated in step 4 & 5 above

