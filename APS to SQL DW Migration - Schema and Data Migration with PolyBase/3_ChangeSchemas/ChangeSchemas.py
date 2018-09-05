#####################################################################################
##-----------------------------------------------------------------------------------                        
## This Python program will automate the APS to SQLDW code migration tasks.
## The program will use exact pattern matching to reduce the code migration risks.
## 
## The program will transform the following code (DDL or DML files):                       
##                                
##  1. Tables 
##  2. Views  
##  3. Stored Procedures (SPs)
##  
## This program will use a custom APS to SQLDW schema mapping matrix 
##   that defines the mapping rules in a configurable CSV File     
## This program will also use a configuration csv file where you 
##   can specify the src directories (for APS code) and output directories (for SQLDW Code)
## 
## The program will work for the following patterns:
##     (1) [APS_DB].[APS_SCHMEA].                     ==> [SQLDW_SCHEMA].      
##           with or without [], (case insensitive) 
##     (2) [APS_SCHMEA].  (based on APS_Base_DB)      ==> [SQLDW_SCHEMA].      
##           with or without [], (case insensitive)   ==> [SQLDW_SCHEMA].      
##     (3)  APS_DB.sys.          (case insensitive)   ==> .sys.   
##     (4)  N'APS_DB.APS_SCHEMA. (case insensitive)   ==> N'SQLDW_SCHEMA. 
##     (5)  'APS_DB.APS_SCHEMA.  (case insensitive)   ==> 'SQLDW_SCHEMA.  
##     (6)  TBD   
##     (n)  Additional patterns can be easily added within the same program structure
##            without breaking the program. 
##  Usage:    
##  
##     (1) Create a "Config directory" to store all your configuratio files, for example: C:\Config\
##     (2) Inside the "Config directory", create a your schema mapping rules in a CSV file 
##             (sample file provided with this program: schemas_sample.csv) 
##     (3) Inside the "Conig directory", create a code migration configuration CSV file to sepcify 
##             (sample file provided with this program: cm_sample.csv) 
##          (i)  Active (It is a flag): "1" or "0" value to be filled. "1" to perform tasks, "0" to skip
##          (iI)   ApsBaseDbName: Where the original APS tables/views/SPs were created
##          (iiI)  SrcDir: Where the APS code (tables/views/SPs) are stored
##          (iv) OutDir: Where the SQLDW code (tables/views/SPs) will be stored
##          (v)  ObjectType: What type of code it is (Table/View/SP)
##          Note:  Recommended SrcDir and OutDir Structures: 
##               SrcDir: C:\Some_Root\APS_BASE_DB_NAME\Tables   OutDir: C:\Another_Root\SQLDW_Schem_01\Tables 
##               SrcDir: C:\Some_Root\APS_BASE_DB_NAME\Views    OutDir: C:\Another_Root\SQLDW_Schem_02\Views
##               SrcDir: C:\Some__Root\APS_BASE_DB_NAME\SPs     OutDir: C:\Another_Root\SQLDW_Schem_03\SPs 
##               Similar 
##     (4) Run the program and provide corresponding file names and exame the results in outDir(s)  
##  
##     Author:  Gaiye "Gail" Zhou    
##   
##  June 2018   
## 
############################################################################################################

import sys
import os
import re
import csv
import shutil
import datetime


startTime = datetime.datetime.now()

fileExt = ".dsql"
print (" ")
configDir = input ("Please enter the path of your configuration files. Press [Enter] if it is 'C:\APS2SQLDW\\3_ChangeSchemas\\\' ") or "C:\\APS2SQLDW\\3_ChangeSchemas\\"

#########################################################################################
## Schema Config file 
schemaConfigFn = input ("Please enter the name of your schema mapping file. Press [Enter] if it is 'schemas.csv' ") or ("schemas.csv")

if not os.path.exists (configDir + schemaConfigFn):
    print (configDir + schemaConfigFn, " does not exist." )
    exit (0)

schemaCsvFile = open(os.path.join(configDir, schemaConfigFn), 'r') 
smMatrix = [] 
schemaReader = csv.reader(schemaCsvFile)
next(schemaReader) # skip header 
smMatrix = [r for r in schemaReader]

#print (smMatrix)
nSchemaRows = len(smMatrix)  # used later in program 
cmmRows = []          # used later in program 

#########################################################################################
## Code Migration Config file 
cmCfgFn = input ("Please enter the name of your code migration config file. Press [Enter] if it is 'cs_dirs.csv' ") or "cs_dirs.csv"

if not os.path.exists (configDir + cmCfgFn):
    print (configDir + cmCfgFn, " does not exist." )
    exit (0)

cmCsvFile = open(os.path.join(configDir, cmCfgFn), 'r') 

cmMatrix = [] 
cmReader = csv.reader(cmCsvFile)
next(cmReader) # skip header 
cmMatrix = [r for r in cmReader]

#print (cmMatrix)
nCmRows = len(cmMatrix)  # used later in program 


#####################################################################
def replaceRow(oneRow, baseDbName, apsDbName, apsSchema, SQLDWSchema):
    newRow = oneRow
    #################################################################
    # For all patterns below, use same newPat until it is redefined. 
    #newPat = " [" + SQLDWSchema + "]."          #leave gap         # ==> [SQLDWSchema].
    newPat = "[" + SQLDWSchema + "]."                              # ==> [SQLDWSchema].

    oldPat = "[" + apsDbName + "].[" + apsSchema + "]."           # [apsDbName].[apsSchema]. 
    repText = re.compile(re.escape(oldPat), re.IGNORECASE)
    newRow = repText.sub(newPat, newRow)

    oldPat = apsDbName + ".[" + apsSchema + "]."                  # apsDbName.[apsSchema].   
    repText = re.compile(re.escape(oldPat), re.IGNORECASE)           
    newRow = repText.sub(newPat, newRow)

    oldPat = "[" + apsDbName + "]." + apsSchema + "."              # [apsDbName].apsSchema.   
    repText = re.compile(re.escape(oldPat), re.IGNORECASE)       
    newRow = repText.sub(newPat, newRow)

    oldPat = apsDbName + "." + apsSchema + "."                     # apsDbName.apsSchema.   
    repText = re.compile(re.escape(oldPat), re.IGNORECASE)
    newRow = repText.sub(newPat, newRow)

    #################################################################
    # for these use cases involving OBJECT_ID()
    #### For all patterns below, use same newPat until it is redefined. 
    newPat = "'[" + SQLDWSchema + "]."  

    # IF OBJECT_ID ('[CSBI_STAGE].[CSS.TMP_TableName]') IS NOT NULL
    oldPat = "'[" + apsDbName + "].[" + apsSchema + "]."           
    repText = re.compile(re.escape(oldPat), re.IGNORECASE) 
    newRow = repText.sub(newPat, newRow)

    # IF OBJECT_ID ('[CSBI_STAGE].CSS.TMP_TableName') IS NOT NULL
    oldPat = "'[" + apsDbName + "]." + apsSchema + "."          
    repText = re.compile(re.escape(oldPat), re.IGNORECASE) 
    newRow = repText.sub(newPat, newRow)

    # IF OBJECT_ID ('CSBI_STAGE.[CSS].TMP_TableName') IS NOT NULL
    oldPat = "'" + apsDbName + ".[" + apsSchema + "]."          
    repText = re.compile(re.escape(oldPat), re.IGNORECASE) 
    newRow = repText.sub(newPat, newRow)

    # IF OBJECT_ID ('CSBI_STAGE.CSS.TMP_TableName') IS NOT NULL
    oldPat = "'" + apsDbName + "." + apsSchema + "."         
    repText = re.compile(re.escape(oldPat), re.IGNORECASE) 
    newRow = repText.sub(newPat, newRow)

    #################################################################
    # System Tables 
    # This is a new set of patterns 
    # For all patterns below, use same newPat until it is redefined. 
    newPat = " sys."                                              # ==> sys. 

    oldPat = "[" + apsDbName + "]" + ".sys."                      # [apsDbName].sys. 
    repText = re.compile(re.escape(oldPat), re.IGNORECASE)  
    newRow = repText.sub(newPat, newRow)

    oldPat = apsDbName + ".sys."                                   # apsDbName.sys. 
    repText = re.compile(re.escape(oldPat), re.IGNORECASE)       
    newRow = repText.sub(newPat, newRow)

    #################################################################
    if (baseDbName.upper() == apsDbName.upper()):                  # [CSS]. need to know baseDbName 
        # For all patterns below, use same newPat until it is redefined.   
        newPat = " [" + SQLDWSchema + "]."                         # => [SQLDWSchema].

        oldPat = " [" + apsSchema + "]."                           # [schema]. with implied DB 
        repText = re.compile(re.escape(oldPat), re.IGNORECASE)
        newRow = repText.sub(newPat, newRow)                       # => [SQLDWSchema].

        oldPat = " " + apsSchema + "."                             # schema.   with implied DB   
        repText = re.compile(re.escape(oldPat), re.IGNORECASE)     
        newRow = repText.sub(newPat, newRow)

        ############################################
        # For IF OBJECT_ID ()
        ### For all patterns below, use same newPat until it is redefined. 
        newPat = "'[" + SQLDWSchema + "]."  
 
        # IF OBJECT_ID ('[CSS].TMP_TableName') IS NOT NULL              
        oldPat = "'[" + apsSchema + "]."                         
        repText = re.compile(re.escape(oldPat), re.IGNORECASE)
        newRow = repText.sub(newPat, newRow)  

        # IF OBJECT_ID ('CSS.TMP_TableName') IS NOT NULL     
        oldPat = "'" + apsSchema + "."                         
        repText = re.compile(re.escape(oldPat), re.IGNORECASE)
        newRow = repText.sub(newPat, newRow)      


    return newRow 

def aps2sqldwCodeMigration(srcDir, outDir, fileName, baseDbName, smMatrix):
    fi = open(os.path.join(srcDir, fileName), 'r') 
    fo = open(os.path.join(outDir, fileName), 'w') 
    for row in fi: 
        cmmRows.append(row)          
        for i in range (0,nSchemaRows):       
            apsDbName = smMatrix[i][0]
            apsSchema = smMatrix[i][1]
            SQLDWSchema = smMatrix[i][2]
            tempRow = replaceRow(cmmRows[i], baseDbName, apsDbName, apsSchema, SQLDWSchema) 
            cmmRows.append(tempRow)
        fo.write(cmmRows[nSchemaRows])  
        cmmRows.clear()   
    fi.close()
    fo.close()


# root - starting point 
# dirs - dirs under root. only files please. no subdirs. 
# files - files under the dir 

# Input Directory Structure:   baseDb/Tables, baseDb/Views  baseDb/SPs 
# Process each type at a time, for each APS DB. 
#
# This will work for all cross DB queries 
#
###################################################################################
#
###################################################################################
# Perform code migration tasks! 
# Two layers of matrixes and nested processing 
# 
for j in range (0, nCmRows):
    active = cmMatrix[j] [0]
    baseDbName = cmMatrix[j] [1]
    srcDir     = cmMatrix[j] [2]
    outDir     = cmMatrix[j] [3]
    objectType = cmMatrix[j] [4]

    if active == "1":
        beginTime = datetime.datetime.now() 
        print (" --------------------------------------------------------------------------------------------------------------- ")    
        if os.path.exists (outDir):
            shutil.rmtree(outDir)
            print ("Previous output directory", outDir, "deleted." )
    
        if not os.path.exists(outDir):
            os.makedirs(outDir)
            print ("New output directory", outDir, "created. New file(s) will be created in this directory." )

        for root, dirs, files in os.walk(srcDir):
            for file in files: 
                if file.endswith(fileExt):                         
                    aps2sqldwCodeMigration(srcDir, outDir, file, baseDbName, smMatrix)  
    
        endTime = datetime.datetime.now() 
        print (" Time started: ", beginTime)  
        print (" Time completed: ", endTime)
        print (" Elapsed Time: ", endTime - beginTime)
    

# check on time and report time spent 
finishTime = datetime.datetime.now()

print (" ")
print ("**********************************************************************")
print (" ")
print ("Program Start Time:   ", startTime)
print ("Program Finish Time:  ", finishTime)
print ("Program Elapsed Time:            ", finishTime - startTime)
print (" ")
print ("All is done! Have a great day!")
print (" ")
print ("**********************************************************************")
print (" ")