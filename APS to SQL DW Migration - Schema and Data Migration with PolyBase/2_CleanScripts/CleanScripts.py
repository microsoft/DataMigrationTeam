##############################################################################################
##-----------------------------------------------------------------------------------                        
## This Python program will clean up the SQLDW code for installations
## It perform makes the DDLs and DMLs ready to be installed in SQLDW:
##    (1) Tables: 
##         (a) Remove unwanted header lines 
##         (b) Remove ";"
##         (c) Remove Indexes and Statistics Statements and put them into a seperate file
##             with Prefix "IDXS_" or STATS_" 
##    (2) Views:
##         (a) Remove unwanted hearder lines until CREATE VIEW Statement
##         (b) Remove ";"
##         (c) Remove last 5 lines 
##    (3) SPs (Stored Procedures)
##         (a) Remove unwatned leading lines until CREATE PROC Statement
##         (b) Remove last 5 lines 
##  Usage:
##    (1) Sample configuratio file called cleancode.csv is created
##   (2) Create a csv config file based on (1)
##    (2) The program will ask for input of the director and file name    
##           
##  Author:  Gaiye "Gail" Zhou    
##   
##  July 2018   
## 
###############################################################################################

import sys
import os
import re
import csv
import shutil
import datetime

startTime = datetime.datetime.now()

fileExt = ".dsql"
print (" ")
#configDir = input ("Please enter the path of your configuration files. Press [Enter] if it is 'C:\Config\\\' ") or "C:\\Config\\"
configDir = input ("Please enter the path of your configuration files. Press [Enter] if it is 'C:\APS2SQLDW\\2_CleanScripts\\\' ") or "C:\\APS2SQLDW\\2_CleanScripts\\"

#########################################################################################
## Code Migration Config file 
cmCfgFn = input ("Please enter the name of your SQLDW post processing config file. Press [Enter] if it is 'clean_scripts.csv' ") or "clean_scripts.csv"


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

def neFile (fp):
    return os.path.isfile(fp) and (os.path.getsize(fp) > 0)


#####################################################################
def cleanUpFile(srcDir, outDir, file, objectType):

    numLines = sum( 1 for line in open (srcDir + file)) # used for processing ending lines 

    fi = open(os.path.join(srcDir, file), 'r') 
    fo = open(os.path.join(outDir, file), 'w')
    idxsFn = "IDXS_" + file
    statsFn = "STATS_" + file
    idxsFp = outDir + idxsFn
    statsFp = outDir + statsFn
    
    
    fidxs = open(os.path.join(outDir, idxsFn), 'w')
    fstas = open(os.path.join(outDir, statsFn), 'w')

    # For each file, start anew 
    oldText = ";"
    newText =""
    oldTextFound = False
    

    crTable = "CREATE TABLE"
    crStats = "CREATE STATISTICS"
    crIndex = "CREATE INDEX"
    crView = "CREATE VIEW"
    crProc = "CREATE PROC"
    prtEnd = "PRINT 'END'"

    crTableFound = False
    crStatsFound = False
    crIndexFound = False
    crViewFound = False
    crProcFound = False 
    prtEndFound = False 
    goFound = False 


    if (objectType.upper() == "TABLE"):
        for row in fi:
            myRow = row 
            if (re.match(crTable, row, re.I)):
                crTableFound = True
            elif (re.match(crStats, row, re.I)):
                crStatsFound = True
            elif (re.match(crIndex, row, re.I)):
                crIndexFound = True
            elif (re.search(oldText, row, re.I)):
                oldTextFound = True
                repText = re.compile(re.escape(oldText), re.IGNORECASE)
                myRow = repText.sub(newText, myRow)
            else:
                pass

            if ((crTableFound) and (not crIndexFound) and (not crStatsFound)):
                fo.write(myRow)
            elif (crTableFound and crIndexFound and (not crStatsFound)):  # found index prior to stats? Verify 
                fidxs.write(myRow) 
            elif (crTableFound and (not crIndexFound) and (crStatsFound)):
                fstas.write(myRow) 
            elif (crTableFound and (crIndexFound) and (crStatsFound)):
                fstas.write(myRow) 
            else:
                pass

    elif (objectType.upper() == "VIEW"):     
        lineCount = 0
        for row in fi:
            myRow = row
            lineCount = lineCount + 1
            if (re.match(crView, row, re.I)):
                crViewFound = True
            if (re.match(prtEnd, row, re.I)):
                prtEndFound = True
            if (re.search(oldText, row, re.I)):
                oldTextFound = True
                repText = re.compile(re.escape(oldText), re.IGNORECASE)
                myRow = repText.sub(newText, myRow)
            #if (crViewFound and (not prtEndFound)):           
            #   fo.write(row)
            if (crViewFound and ((numLines - lineCount) >= 5)):
                fo.write(myRow)
            else:
                pass

    elif (objectType.upper() == "SP"):
        lineCount = 0
        for row in fi:
            myRow = row
            lineCount = lineCount + 1
            if (re.match(crProc, row, re.I)):
                crProcFound = True
            if (re.match(prtEnd, row, re.I)):
                prtEndFound = True
            #if (crProcFound and (not prtEndFound)):            
            #   fo.write(row)
            if (crProcFound and ((numLines - lineCount) >= 5)):  
                fo.write(myRow)
            else:
                pass 
    else:
        pass
        print ("Somthing wrong with the Object Type. I expect Table, View, or SP")
    
    fi.close()
    fo.close()
 
    fidxs.close()
    fstas.close()

    if (neFile (idxsFp)):
        pass
    else:
        os.remove(idxsFp)

    if (neFile (statsFp)):
        pass
    else:
        os.remove(statsFp)

# root - starting point 
# dirs - dirs under root. only files please. no subdirs. 
# files - files under the dir 

# Input Directory Structure:   baseDb/Tables, baseDb/Views  baseDb/SPs 
# Process each type at a time, for each APS DB. 
#
# This will work for all cross DB queries 


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
                    cleanUpFile(srcDir, outDir, file, objectType)  
    
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