
# **1_CreateMPPScripts (PowerShell):** Create MPP Scripts from APS


## **How to Run the Program** ##

The program processing logic and information flow is illustrated in the diagram below: 

![Step 1: CreateMppObjects](https://i.imgur.com/cazsRYU.jpg)

Below are the steps to run the PowerShell Programs: 

**Step 1:** Download [DWScripter]( https://github.com/Microsoft/DWScripter "DWScripter Github Page") (^^^Need Version Number^^^) from github and place the exe on the machine to run the PowerShell scripts: ScriptMPPObjectsDriver.ps1 and ScriptObjectsToDSQL.ps1.

**Step 2:** Create configuration driver CSV file(s) required for ScriptMPPObjectsDriver.ps1. Refer the "Preparation Task: Configuration Driver CSV File Setup" after the steps for more details. 


**Step 3:** Edit Line 23 of the ScriptObjectsToDSQL.ps1 to identify the location of the dwScripter.exe:

```
$cmd = 'C:\PDWScripter\dwScripter.exe -S:"' + $ServerName + '" -D:' + $DatabaseName
```

**Step 4:** Run the program ScriptMPPObjectsDriver.ps1, provides information prompted or accept default values. The ScriptMPPObjectsDriver.ps1 will  prompt for the following information:


1. The directory where the configuration driver CSV file(s) reside. The configuration CSV file(s) contains all the object names (Table/View/SP), along with values of other required parameters. Refer the "Preparation Task: Configuration Driver File Setup" for more details. 

2. Security access information (Yes/No for Integrated Security or Not).

3. User Name and Password for the MPP system (If integrated security is not set up). 


**Preparation Task: Configuration Driver CSV File Setup**

Create the configuration driver CSV file by referring the definitions below. Sample CSV configuration files are provided to aid this preparation task. Initial configuration files can also be automatically generated using the PowerShell program for PreAssessment. 

| Parameter           | Purpose                              |      Value (Sample)     |
| --------------------| -------------------------------------|-------------------------| 
| Active              | 1 – Run line, 0 – Skip line.         | 0 or 1                  |
| ServerName          | Name of the SQLDW/APS(PDW).          | Sqlsvr.database.windows.net  or “10.111.###.333,17001”                                                                 |
| DatabaseName        | Name of the DB to connect to.        | YourDatabaseName        |
| SchemaName        | Schema name of the object.            | dbo, DBO, HR, Sales     |
| WorkMode            | DDL – script the DDL for the tables. DML – script the SP/Views.                                | DDL or DML          |
| OutputFolderPath    | Path where the .sql file should be saved.  Must have “\” on end.                                | C:\temp\APS_Scripts\Db1Folder                  |
| FileName            | Name of the File to store the script in.  This should match the object name if possible.                               | DimAccount                  |
| Mode                | DWScripter variable for Mode.        | Full                    |
| ObjectName          | Name of the object to script.  This must include the schema.  If the schema is not added, dbo is assumed.  Should you want all the objects in all schemas the value entered should be %.objectName.    | Dbo.DimAccount or Sales.DimAccount |
| ObjectToScript      | Used in logging only.                | SP, View, Table |


## **What the Program(s) Does** ##

The PowerShell program(s) scripts out specified meta data such as table definition, view definition, and stored procedure definitions for the objects specified in a configuration driver CSV file. The output is stored in the file folders specified by the same configuration file. 


