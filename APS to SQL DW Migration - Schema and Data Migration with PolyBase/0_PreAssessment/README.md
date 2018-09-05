
# **0_PreAssessment and Scoping Tool (PowerShell):** Assess the APS System and Summarize Information for Scoping the Migration Effort

## **How to Run the APS Pre-Assessment Program**

The program processing logic and information flow is illustrated in the diagram below: 

![Preassessment Programs](https://i.imgur.com/okLZNvo.jpg)
Below are the steps to run the PowerShell Program(s): 


**Step 1:** Create configuration driver CSV file required for the PowerShell Scripts. Refer the "Preparation Task: Configuration Driver CSV File Setup" after the steps for more details. 


**Step 2:** Run the PowerShell script (PreAssessmentDriver.ps1). This script will prompt for the following information: 

* “Enter the name of the SQLScriptToRun.csv File.”
	* This will be the location and name of the config File SQLScriptToRun.csv.
	* Default Name and Location: C:\APS2SQLDW\0_PreAssessment\SQLScriptToRun.csv

* “Enter the Path of the Output File Directory.”
	* This will be the location for all the results (output files)
	* Default Location: C:\APSPreAssessment\Output\0_PreAssessment

* “Enter the name of the Server”
	* This is the APS server you are wanting to connect to:  “aps,17001” or “APS Server IP Address, 17001” 

* “Enter 'Yes' to connect using Integrated security security, otherwise Enter 'No' ”
	* Allows YES or No 

* If No to last question, “Enter the User Name if not using Integrated:” 
	* User name with permission run the scripts
	
* “PDW Password”
	* Enter the Password for the user – reads password as a secure string


**Preparation Task: Configuration Driver CSV Files and PowerShell Setup**

Create the Configuration Driver CSV File based on the definition below. Sample CSV configuration file is provided to aid this preparation task. 

Note: You need to open the CSV (default name: SQLScriptstoRun.csv) file, replace the IP address with your own MPP server IP address in the cell F8, F9, and F10. Look for this line of code that looks like this: 
Declare @ServerName varchar(50)= '10.###.222.###'. 


| Parameter                                                                                                                                            | Purpose                                                                                                                          | Value   (Sample)                                     |
|------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------|
| Active                                                                                                                                               | 1 – Run line, 0 – Skip line                                                                                                      | 0 or 1                                               |
| RunForEachDB                                                                                                                                         | 1 – yes, 0 = no                                                                                                                  | 0 or 1                                               |
| If set to 1, this will loop through each DB on the APS and   run the SQL Statement.  Currently This does not support running for   a single DB.      |                                                                                                                                  |                                                      |
| RunForEachTable                                                                                                                                      | 1 – yes, 0 = no                                                                                                                  | 0 or 1                                               |
| If set to 1, this will loop through each Table int eh DB   and run the SQL Statement.  Currently This does not support running for   a single Table. |                                                                                                                                  |                                                      |
| DBCCStatement                                                                                                                                        | 1 – yes, 0 = no                                                                                                                  | 0 or 1                                               |
| Identifies if the statement is a dbcc command.  Currently this only   supports pdw_Showspaceused.                                                    |                                                                                                                                  |                                                      |
| ExportFilename                                                                                                                                       | Name of the output file to save the sql statement results.  Datetime will be added to the end of the   filename along with .csv. | ObjectCount                                          |
| FileName                                                                                                                                             | Name of the File to store the script in.  This should match the object name if   possible                                        | DimAccount                                           |
| SQLStatement                                                                                                                                         | SQL Statement to run                                                                                                             | Any SQL statement is valid at the table or DB level. However, inside the T-SQL Statements where APS server name is specified: Declare @ServerName varchar(50)= ‘10.###.222.###’, the masked IP address needs to be replaced with the actual APS IP Address or APS server name. |


## **What the APS Pre-Assessment Program Does** ##

The APS Pre-Assessment PowerShell scripts gather information on the APS system to better enable an accurate estimate for the migration.  This script captures the following info:

1. Version of the APS system – @@version - Version_{Datetime}.csv
2. Count of all objects in all DB’s in the APS. – sys.objects - ObjectCount_{Datetime}.csv
3. List of all tables and their attributes (distribution type, # partitions, storage type and Distribution column) – various system tables – TableMetadata_{DateTime}.csv
4. Listing of the ShowSpaceUsed for all tables. – DBCC pdw_showspaceused – ShowSpaceUsed_{Datetime}.csv
5. Report the number of nodes and total number of distributions on the APS.
6. List of Tables with table name, schema name, and database name in a CSV file that can be used to script out the "Create Table" Statements. 
7. List of Views with view name, schema name, and database name in a CSV file that can be used to script out the "Create View" Statements. 
8. List of Stored Procedures with stored procedure name, schema name, and database name in a CSV file that can be used to script out the "Create Proc" Statements. 
  
Notes:  

- Uses Invoke-sqlcmd
- Dbcc pdw_showspaceused – errors on external tables but continues to run.  Using is_external to filter the tables can cause errors on older versions of APS.  


## **How to Run the Scoping Tool**

The program processing logic and information flow is illustrated in the diagram below: 

![The Scoping Tool](https://i.imgur.com/asG4HlX.jpg)

**Prerequisite** for running the scoping tool (on top of PowerShell): Install-Module ImportExcel  (Run the command from a PS command prompt.  Command Prompt must be running as admin)

The Scoping Tool pulls the newest files based on date from the Assessment into Excel.  

Below is information how to run this the one-step scoping Tool:

**Step 1:** Run the PowerShell script (CopyDataToExcel.ps1).  This script will prompt for the following information:

* “Enter the Path to the Pre-Assessment output files.” – This will be the location\name of the pre-Assessment output.
	* Default Location: C:\APS2SQLDW\output\0_PreAssessment
* “Enter the Path to save excel file.”
	* Default Location: C:\APS2SQLDW\output\0_PreAssessment
* “Enter the name of the Excel File”
	* Default File Name: "Pre-Assessment.xlsx"



## **What the Scoping Tool Does**

The output results of the APS Pre-Assessment, in the form of the CSV files, are summarized to assist in scoping the APS migration to Azure SQLDW. The summarized information is stored into an Excel PowerPivot model and sliced on the necessary info to give counts and table sizes.

The diagrams below shows the sample results of a APS system: 


![The Scoping Tool (PowerShell) Diagram 2](https://i.imgur.com/FFpAWqP.jpg)
