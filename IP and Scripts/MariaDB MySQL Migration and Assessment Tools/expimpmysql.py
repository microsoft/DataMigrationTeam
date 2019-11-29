#!/bin/python36
# $Id: expimpmysql.py 208 2019-11-29 00:21:53Z bpahlawa $
# Created 22-NOV-2019
# $Author: bpahlawa $
# $Date: 2019-11-29 11:21:53 +1100 (Fri, 29 Nov 2019) $
# $Revision: 208 $

import re
from string import *
import pymysql
from sqlalchemy.dialects.mysql import LONGTEXT
from io import StringIO,BytesIO
from struct import pack
import gzip
import subprocess
import configparser
import os
import getopt
import sys
import subprocess
import threading
import time
import getpass
import base64
import random
import signal
import io
import glob
import logging
import datetime
import readline
import shutil

from itertools import (takewhile,repeat)
from multiprocessing import Pool, Manager

#global datetime
dtnow=None
#foreign key script's filename
crfkeyfilename='crforeignkey.sql'
#other key script's filename
crokeyfilename='crotherkey.sql'
#create table script's filename
crtblfilename='crtable.sql'
#create trigger script's filename
crtrigfilename='crtrigger.sql'
#create sequence script's filename
crseqfilename='crsequences.sql'
#create view script's filename
crviewfilename='crviews.sql'
#create analyze db report
cranalyzedbfilename='analyzedb'
#spool out all schema_information
crallinfo='allinfo'
#create proc and func script's filename
crprocfuncfilename='crprocfunc.sql'

#create table file handle
crtblfile=None
#import cursor
impcursor=None
#import connection
impconnection=None
#export connection
expconnection=None
#mode either export or import
mode=None
#config file handle
config=None
#export chunk of rows
exprowchunk=None
#import chunk of rows
improwchunk=None
#import tables
imptables=None
#export tables
exptables=None
#config filename
configfile=None
#signal handler
handler=None
#total proc
totalproc=0
#cursort tableinfo
curtblinfo=None
#export max rows per file
expmaxrowsperfile=None
expdatabase=None
#report file
afile=None


sqlanalyzetableinfo="""
select table_schema,
       table_name,
       table_type,
       ROW_FORMAT,
       TABLE_ROWS,
       AVG_ROW_LENGTH,
       DATA_LENGTH,
       INDEX_LENGTH 
from information_schema.tables 
where table_schema = '{0}'
order by 2,1,4,3;
"""

sqlanalyzeprocfuncinfo="""
select
SPECIFIC_NAME,
ROUTINE_CATALOG,
ROUTINE_NAME,
ROUTINE_TYPE,
DATA_TYPE,
CHARACTER_MAXIMUM_LENGTH,
CHARACTER_OCTET_LENGTH,
NUMERIC_PRECISION,
NUMERIC_SCALE,
DATETIME_PRECISION,
CHARACTER_SET_NAME,
COLLATION_NAME,
DTD_IDENTIFIER,
ROUTINE_BODY,
EXTERNAL_NAME,
EXTERNAL_LANGUAGE,
PARAMETER_STYLE,
IS_DETERMINISTIC,
SQL_DATA_ACCESS,
SQL_PATH,
SECURITY_TYPE,
CREATED,
LAST_ALTERED,
SQL_MODE,
ROUTINE_COMMENT,
DEFINER,
CHARACTER_SET_CLIENT,
COLLATION_CONNECTION,
DATABASE_COLLATION from information_schema.routines
where routine_schema='{0}'
"""

sqlanalyzeplugin="""
select plugin_name,plugin_version,plugin_type,plugin_maturity, load_option,plugin_license,plugin_author,plugin_description
 from information_schema.all_plugins
where plugin_name not like 'INNODB%' and plugin_status='ACTIVE'
"""




sqlanalyzelanguage="select lanname from pg_catalog.pg_language order by 1"
sqlanalyzeusedfeature="""
SELECT  rolname,proname,lanname,proname,typname
FROM    pg_catalog.pg_namespace n
JOIN    pg_catalog.pg_authid a ON nspowner = a.oid
JOIN    pg_catalog.pg_proc p ON pronamespace = n.oid
JOIN    pg_catalog.pg_type t ON typnamespace = n.oid
JOIN    pg_catalog.pg_language l on prolang = l.oid where nspname in (select schema_name from information_schema.schemata
where schema_name not in ('pg_catalog','information_schema','sys','dbo'))
"""


#SQL Statement for creating triggers
sqlcreatetrigger="show triggers"

sqllistprocfuncs="""
select routine_type,routine_name
from information_schema.routines
where routine_schema = '{0}'
order by routine_name
"""

sqllistparams="""
select concat('CREATE ',routine_type,' ',specific_name,'(') cr ,concat(parameter_mode,' ',parameter_name,' ',dtd_identifier) param 
from information_schema.parameters where specific_schema='{0}' and specific_name='{1}' and routine_type='{2}'
"""

#SQL Statement for creating foreign keys
sqlcreatefkey="""
SELECT 'ALTER TABLE '||nspname||'.'||relname||' ADD CONSTRAINT '||conname||' '|| pg_get_constraintdef(pg_constraint.oid)||';'
FROM pg_constraint
INNER JOIN pg_class ON conrelid=pg_class.oid
INNER JOIN pg_namespace ON pg_namespace.oid=pg_class.relnamespace and pg_namespace.nspname not in ('sys')
where pg_get_constraintdef(pg_constraint.oid) {0} '%FOREIGN KEY%'
ORDER BY CASE WHEN contype='f' THEN 0 ELSE 1 END DESC,contype DESC,nspname DESC,relname DESC,conname DESC
"""

#SQL Statement for creating sequence
sqlcreatesequence="show create sequence"

#Statement for listing all tables
sqllisttables="show full tables where table_type='BASE TABLE'"

#Statement for creating table
sqlcreatetable="show create table"

#List name of tables and their sizes
sqltableinfo="""select table_name,round(((data_length + index_length) / 1024 / 1024), 2) rowsz 
from information_schema.tables 
where table_schema='{0}' and table_type='BASE TABLE'"""

#procedure to trap signal
def trap_signal(signum, stack):
    logging.info("Ctrl-C has been pressed!")
    sys.exit(0)

#procedure to count number of rows
def rawincount(filename):
    f = gzip.open(filename, 'rt')
    bufgen = takewhile(lambda x: x, (f.read(8192*1024) for _ in repeat(None)))
    return sum( buf.count('\n') for buf in bufgen )

#procedure for crypting password
def Crypt(string,key,encrypt=1):
    random.seed(key)
    alphabet = 2 * " AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890.;:,'?/|{}[]-=+_!@#$%^&*()<>`~"
    lenalpha = int(len(alphabet)/2)
    if encrypt:
        return ''.join([alphabet[alphabet.index(string[p]) + lenalpha - int(lenalpha * random.random())] for p in range(len(string))])
    else:
        return ''.join([alphabet[alphabet.index(string[p]) - lenalpha + int(lenalpha * random.random())] for p in range(len(string))])

#procedure to encode password
def encode_password(thepass):
    return(Crypt(thepass,'bramisalwayscool'))

#procedure to decode password
def decode_password(thepass):
    return(Crypt(thepass,'bramisalwayscool',encrypt=0))

#procedure to read configuration from mysqlconfig.ini file
def read_config(section,key):
    global config,configfile
    try:
       value=config[section][key]
       return(value)
    except (Exception,configparser.Error) as error:
       logging.error("\033[1;31;40mread_config: Error in reading config "+configfile, str(error))
       sys.exit(2)

#procedure to generate forign keys creation script 
def generate_create_fkey():
    global curtblinfo,expdatabase
    try:
       curtblinfo.execute(sqlcreatefkey.format('like'))
       rows=curtblinfo.fetchall()
       fkeyfile = open(expdatabase+"/"+crfkeyfilename,"w")
  
       for row in rows:
          fkeyfile.write(row[0]+"\n")

    except Exception as error:
       logging.error('\033[1;31;40mgenerate_create_fkey: Error occured: '+str(error))
       sys.exit(2)
    finally:
       if (fkeyfile):
          fkeyfile.close() 

#procedure to generate sequences creation script
def generate_create_sequence():
    logging.info("Generating create sequence script...")
    global curtblinfo,expdatabase
    try:
       listofsequence=[]
       curtblinfo.execute("show full tables where table_type='SEQUENCE'")
       rows=curtblinfo.fetchall()
       for row in rows:
           listofsequence.append(row[0])

       fseqfile = open(expdatabase+"/"+crseqfilename,"w")
       for sequence_name in listofsequence:
           curtblinfo.execute(sqlcreatesequence+" "+sequence_name)
           rows=curtblinfo.fetchall()
           for row in rows:
               fseqfile.write(row[1]+";\n")

    except Exception as error:
       logging.error('\033[1;31;40mgenerate_create_sequence: Error occured: '+str(error))
       sys.exit(2)
    finally:
       if (fseqfile):
          fseqfile.close() 

#procedure to generate views creation script
def generate_create_view():
    logging.info("Generating create view script...")
    global curtblinfo,expdatabase
    try:
       listofview=[]
       curtblinfo.execute("show full tables where table_type='VIEW'")
       rows=curtblinfo.fetchall()
       for row in rows:
           listofview.append(row[0])

       fviewfile = open(expdatabase+"/"+crviewfilename,"w")
       for view_name in listofview:
           curtblinfo.execute("show create view "+view_name)
           rows=curtblinfo.fetchall()
           for row in rows:
               fviewfile.write(row[1]+";\n")

    except Exception as error:
       logging.error('\033[1;31;40mgenerate_create_view: Error occured: '+str(error))
       sys.exit(2)
    finally:
       if (fviewfile):
          fviewfile.close() 

#procedure to generate procedure creation script
def generate_create_proc_and_func():
    logging.info("Generating create procedure and function script...")
    global curtblinfo,expdatabase
    try:
       listofprocfunc=[]
       curtblinfo.execute(sqllistprocfuncs.format(expdatabase))
       rows=curtblinfo.fetchall()
       for row in rows:
           listofprocfunc.append("SHOW CREATE "+row[0]+" "+row[1])

       fprocfuncfile = open(expdatabase+"/"+crprocfuncfilename,"w")

       i=0
       for procfuncname in listofprocfunc:
           curtblinfo.execute(procfuncname)
           rows=curtblinfo.fetchall()
           for row in rows:
               if (row[2]==None):
                   logging.info("missing privilege \"grant select on mysql.proc to thisuser\", skipping create procedure and function...")
                   fprocfuncfile.close()
                   return
                   
               if (i==0):
                  fprocfuncfile.write("delimiter ;;\n")
                  i+=1
               fprocfuncfile.write(row[2]+"\n")
           fprocfuncfile.write(";;\n")

    except Exception as error:
       logging.error('\033[1;31;40mgenerate_create_proc_and_func: Error occured: '+str(error))
       sys.exit(2)
    finally:
       if (fprocfuncfile):
          fprocfuncfile.close() 

#procedure to generate triggers creation script 
def generate_create_trigger():
    logging.info("Generating create trigger script...")
    global curtblinfo,expdatabase
    try:
       listoftrigger=[]
       curtblinfo.execute(sqlcreatetrigger)
       rows=curtblinfo.fetchall()
       for row in rows:
           listoftrigger.append(row[0])

       trigfile = open(expdatabase+"/"+crtrigfilename,"w")

       for trigger_name in listoftrigger:  
           curtblinfo.execute("show create trigger "+trigger_name)
           rows=curtblinfo.fetchall()
           for row in rows:
               trigfile.write(row[2]+";\n")

    except Exception as error:
       logging.error('\033[1;33;40mgenerate_create_trigger: Error occured: '+str(error))
       sys.exit(2)
    finally:
       if (trigfile):
          trigfile.close() 

#procedure to generate other keys creation script   
def generate_create_okey():
    global curtblinfo,expdatabase
    try:
       curtblinfo.execute(sqlcreatefkey.format('not like'))
       rows=curtblinfo.fetchall()
       okeyfile = open(expdatabase+"/"+crokeyfilename,"w")
  
       for row in rows:
          okeyfile.write(row[0]+"\n")

    except (Exception,configparser.Error) as error:
       logging.error('\033[1;33;40mgenereate_create_okey: Error occured: '+str(error))
       sys.exit(2)
    finally:
       if (okeyfile):
          okeyfile.close() 
       
#procedure to generate tables creation script
def generate_create_table(tablename):
    global curtblinfo
    global crtblfile
    try:
       curtblinfo.execute(sqlcreatetable+" "+tablename)
       rows=curtblinfo.fetchall()

       for row in rows:
          crtblfile.write(row[1]+";\n")
    
    except (Exception,configparser.Error) as error:
       logging.error('\033[1;33;40mgenerate_create_table: Error occured: '+str(error))
       pass

#procedure to create table
def create_table():
    global impconnection,expdatabase
    curcrtable=impconnection.cursor()
    createtable=""
    crtblfailed=[]
    logging.info("Creating tables from the script")
    try:
       fcrtable = open(expdatabase+"/"+crtblfilename,"r")
       curcrtable.execute("SET FOREIGN_KEY_CHECKS=0;")
       for line in fcrtable.readlines():
          if line.find(";") != -1:
             try:
                curcrtable.execute(createtable+line)
                impconnection.commit()
             except (Exception,configparser.Error) as error:
                if str(error).find("Foreign key constraint is incorrectly formed"):
                   crtblfailed.append(createtable+line) 
                elif not str(error[1]).find("already exists"):
                   logging.error("\033[1;31;40m"+str(error))
                else:
                   logging.error('create_table: Error occured: '+str(error))
                impconnection.rollback()
                pass
             createtable=""
          else:
             if createtable=="":
                logging.info("\033[1;33;40mExecuting...."+line)
             createtable+=line

       fcrtable.close()

       createtable=""
       curcrtable.execute("SET FOREIGN_KEY_CHECKS=1;")
          
    except Exception as error:
       logging.error('\033[1;31;40mcreate_table: Error occured: '+str(error))

#procedure to create table's keys
def create_table_keys():
    global impconnection,expdatabase
    curcrtablekeys=impconnection.cursor()
    createtablekeys=""
    logging.info("Creating table's KEYs from the script")
    try:
       fcrokey = open(expdatabase+"/"+crokeyfilename,"r")
       for line in fcrokey.readlines():
          if line.find(");"):
             try:
                curcrtablekeys.execute(createtablekeys+line)
                impconnection.commit()
             except (Exception,configparser.Error) as error:
                if not str(error).find("already exists"):
                   logging.error('create_table_keys: Error occured: '+str(error))
                else:
                   logging.error("\033[1;31;40m"+str(error))
                impconnection.rollback()
                pass
             createtablekeys=""
          else:
             if createtablekeys=="":
                logging.info("\033[1;33;40mExecuting...."+line)
             createtablekeys+=line

       fcrokey.close()
          
    except Exception as error:
       loggin.error('create_table_keys: Error occured: '+str(error))

#procedure to create sequences
def create_sequences():
    global impconnection,expdatabase
    curcrsequences=impconnection.cursor()
    createsequences=""
    logging.info("Creating sequences from the script")
    try:
       crseqs = open(expdatabase+"/"+crseqfilename,"r")
       for line in crseqs.readlines():
          if line.find(");"):
             try:
                curcrsequences.execute(createsequences+line)
                impconnection.commit()
             except (Exception,configparser.Error) as error:
                logging.info('create_sequences: Error occured: '+str(error))
                impconnection.rollback()
                pass
             createsequences=""
          else:
             if createsequences=="":
                logging.info("\033[1;33;40mExecuting...."+line)
             createsequences+=line

       crseqs.close()
          
    except Exception as error:
       logging.error('\033[1;31;40mcreate_sequences: Error occured: '+str(error))

#procedure to re-create foreign keys from the generated script
def recreate_fkeys():
    global impconnection,expdatabase
    curfkeys=impconnection.cursor()
    createfkeys=""
    logging.info("Re-creating table's FOREIGN KEYs from the script")
    try:
       fcrfkey = open(expdatabase+"/"+crfkeyfilename,"r")
       for line in fcrfkey.readlines():
          if line.find(");"):
             try:
                curfkeys.execute(createfkeys+line)
                impconnection.commit()
                logging.info(createfkeys+line+"....OK")
             except (Exception,pymysql.Error) as error:
                if not str(error).find("already exists"):
                   logging.info('recreate_fkeys: Error occured: '+str(error))
                else:
                   logging.error("\033[1;31;40m"+str(error))
                impconnection.rollback()
                pass
             createfkeys=""
          else:
             if createfkeys=="":
                logging.info("\033[1;33;40mExecuting...."+line)
             createfkeys+=line

       fcrfkey.close()
       curfkeys.close()
          
    except Exception as error:
       logging.error('\033[1;31;40mrecreate_fkeys: Error occured: '+str(error))

#preparing text 
def prepare_text(dat):
    cpy = StringIO()
    for row in dat:
       cpy.write('\t'.join([str(x).replace('\t','\\t').replace('\n','\\n').replace('\r','\\r').replace('None','\\N') for x in row]) + '\n')
    return(cpy)

#insert data into table
def insert_data(tablename):
    global impconnection
    global impcursor
    cpy = StringIO()
    thequery = "select * from " + tablename
    impcursor.execute(thequery)
    i=0
    while True:
       i+=1
       records = impcursor.fetchmany(improwchunk) 
       if not records:
           break 
       cpy = prepare_text(records)
       if (i==1):
           cpy.seek(0)

       impcursor.copy_from(cpy,tablename)
       logging.info("Inserted "+str(i*improwchunk)+" rows so far")
    impcursor.close()

#insert data from file
def insert_data_from_file(tablefile,impuser,imppass,impserver,impport,impcharset,impdatabase,improwchunk,dirname):
    try:
       filename=tablefile+".csv.gz"
       tablename=".".join(tablefile.split(".")[0:2])
       
       insconnection=pymysql.connect(user=impuser,
                                      password=imppass,
                                      host=impserver,
                                      port=int(impport),
                                      charset=impcharset,
                                      database=impdatabase,local_infile=True)

       curinsdata=insconnection.cursor()

       logging.info("Inserting data from \033[1;34;40m"+filename+"\033[1;37;40m to table \033[1;34;40m"+tablename)

       if os.path.isfile(dirname+"/"+filename):
          with gzip.open(dirname+"/"+filename,"rb") as f_in:
             with open(dirname+"/"+tablefile+".csv","wb") as f_out:
                shutil.copyfileobj(f_in,f_out)
       else:
          logging.info("File "+dirname+"/"+filename+" doesnt exist!, so skipping import to table "+tablename)
          insconnection.rollback()
          return()

       curinsdata.execute("SET FOREIGN_KEY_CHECKS=0;")
       curinsdata.execute("LOAD DATA LOCAL INFILE '"+dirname+"/"+tablefile+".csv' into table "+impdatabase+"."+tablename+" fields terminated by '\\t' ignore 1 LINES;")
       insconnection.commit()
       curinsdata.execute("SET FOREIGN_KEY_CHECKS=1;")

       logging.info("Data from \033[1;34;40m"+dirname+"/"+filename+"\033[1;37;40m has been inserted to table \033[1;34;40m"+tablename+"\033[1;36;40m")
       os.remove(dirname+"/"+tablefile+".csv")
       
       

    except (Exception,pymysql.Error) as error:
       print ("insert_data_from_file: Error :"+str(error))

    finally:
       if(insconnection):
          insconnection.commit()
          curinsdata.close()
          insconnection.close()

#verify data
def verify_data(tablename,impuser,imppass,impserver,impport,impcharset,impdatabase,improwchunk,dirname):
    if len(tablename.split("."))>2:
       return()
    try:
       vrfyconnection=pymysql.connect(user=impuser,
                                      password=imppass,
                                      host=impserver,
                                      port=int(impport),
                                      charset=impcharset,
                                      database=impdatabase)

       curvrfydata=vrfyconnection.cursor()
       curvrfydata.execute("select count(*) from "+".".join(tablename.split(".")[0:2]))
       rows=curvrfydata.fetchall()
       for row in rows:
           rowsfromtable=row[0]


       rowsfromfile=0
       for thedumpfile in glob.glob(dirname+"/"+tablename+".*.csv.gz"):
           rowsfromfile+=rawincount(thedumpfile)-1          

       for thedumpfile in glob.glob(dirname+"/"+tablename+".csv.gz"):
           rowsfromfile+=rawincount(thedumpfile)-1          

       if (rowsfromfile==-1):
          rowsfromfile=0
       if rowsfromfile==rowsfromtable:
          logging.info("Table \033[1;34;40m"+tablename+"\033[0;37;40m no of rows: \033[1;36;40m"+str(rowsfromfile)+" does match!\033[1;36;40m")
       else:
          logging.info("Table \033[1;34;40m"+tablename+"\033[1;31;40m DOES NOT match\033[1;37;40m")
          logging.info("      Total Rows from \033[1;34;40m"+tablename+" file(s) = \033[1;31;40m"+str(rowsfromfile))
          logging.info("      Total Rows inserted to \033[1;34;40m"+tablename+"  = \033[1;31;40m"+str(rowsfromtable))
       

    except (Exception,pymysql.Error) as error:
       logging.error("\033[1;31;40mverify_data : Error :"+str(error))

    finally:
       if(vrfyconnection):
          curvrfydata.close()
          vrfyconnection.close()

#procedure how to use this script
def usage():
    print("\nUsage: \n   "+
    os.path.basename(__file__) + " [OPTIONS]\nGeneral options:")
    print("   -e, --export        export mode\n   -i, --import        import mode")
    print("   -s, --script        generate scripts")
    print("   -d, --dbinfo        gather DB information")
    print("   -a, --all-info      gather All information from information_schema")
    print("   -l, --log=          INFO|DEBUG|WARNING|ERROR|CRITICAL\n")

def test_connection(t_user,t_pass,t_server,t_port,t_charset,t_database):
    try:
       impconnection = pymysql.connect(user=t_user,
                                        password=t_pass,
                                        host=t_server,
                                        port=int(t_port),
                                        charset=t_charset,
                                        database=t_database)

       impconnection.close()
       return(0)
    except (Exception, pymysql.Error) as logerr:
       if (str(logerr).find("Access Denied")>0):
          print("\033[1;31;40m"+str(logerr))
          return(1)
       elif (str(logerr).find("Can't connect to"))>0:
          print("\033[1;31;40m"+str(logerr)+" ,Exiting......\033[0m")
          if(impconnection): impconnection.close()
          exit(1)
       else:
          print("\033[1;31;40mOther Error occurred: "+str(logerr))
          return(1)
    

#procedure to import data
def import_data():
    global imptables,config,configfile,curimptbl,expdatabase
    #Loading import configuration from mysqlconfig.ini file
    impserver = read_config('import','servername')
    impport = read_config('import','port')
    impuser = read_config('import','username')
    impdatabase = read_config('import','database')
    impcharset = read_config('import','charset')
    expdatabase = read_config('export','database')
    improwchunk = read_config('import','rowchunk')
    impparallel = int(read_config('import','parallel'))
    imppass = read_config('import','password')
    if (imppass==''):
       imppass=' '
    imppass=decode_password(imppass)

    while test_connection(impuser,imppass,impserver,impport,impcharset,impdatabase)==1:
       imppass=getpass.getpass("Enter Password for "+impuser+" :")
    obfuscatedpass=encode_password(imppass)
    config.set("import","password",obfuscatedpass)
    with open(configfile, 'w') as cfgfile:
       config.write(cfgfile)
       

    imptables=read_config('import','tables')

    logging.info("Importing Data to Database: "+impdatabase+" Server: "+impserver+":"+impport+" username: "+impuser)

    global sqllisttables
    global sqltablesizes
    global impconnection
    try:
       impconnection = pymysql.connect(user=impuser,
                                        password=imppass,
                                        host=impserver,
                                        port=int(impport),
                                        charset=impcharset,
                                        database=impdatabase)

    except (Exception, pymysql.Error) as logerr:
       logging.error("\033[1;31;40mimport_data: Error: "+str(logerr))
       sys.exit()

    try:
       curimptbl = impconnection.cursor()

       create_table()

       #create_table_keys()

       listofdata=[]

       curimptbl.execute(sqllisttables)
       rows = curimptbl.fetchall()
     
       for row in rows:
          if imptables=="all":
              if os.path.isfile(expdatabase+"/"+row[0]+".csv.gz"):
                 logging.info("Truncating table \033[1;34;40m"+row[0]+"\033[1;37;40m in progress")
                 curimptbl.execute("SET FOREIGN_KEY_CHECKS=0;")
                 curimptbl.execute("truncate table "+row[0]+";")
                 curimptbl.execute("SET FOREIGN_KEY_CHECKS=1;")
                 listofdata.append(row[0])
                 for slicetbl in glob.glob(expdatabase+"/"+row[0]+".*.csv.gz"):
                     listofdata.append(slicetbl.split("/")[1].replace(".csv.gz",""))
                    
              else:
                 logging.info("File "+expdatabase+"/"+row[0]+".csv.gz doesnt exist")
          else:
              selectedtbls=imptables.split(",")
              for selectedtbl in selectedtbls:
                  if selectedtbl!=row[0]:
                     continue
                  else:
                     if os.path.isfile(expdatabase+"/"+row[0]+".csv.gz"):
                        logging.info("Truncating table \033[1;34;40m"+row[0]+"\033[1;37;40m in progress")
                        curimptbl.execute("SET FOREIGN_KEY_CHECKS=0;")
                        curimptbl.execute("truncate table "+row[0]+";")
                        curimptbl.execute("SET FOREIGN_KEY_CHECKS=1;")
                        listofdata.append(row[0])
                        for slicetbl in glob.glob(expdatabase+"/"+row[0]+".*.csv.gz"):
                            listofdata.append(slicetbl.split("/")[1].replace(".csv.gz",""))
                     else:
                        logging.info("File "+expdatabase+"/"+row[0]+".csv.gz doesnt exist")

       impconnection.commit()
       impconnection.close()

       with Pool(processes=impparallel) as importpool:
          multiple_results = [importpool.apply_async(insert_data_from_file, (tbldata,impuser,imppass,impserver,impport,impcharset,impdatabase,improwchunk,expdatabase)) for tbldata in listofdata]
          print([res.get(timeout=1000000) for res in multiple_results])
       
       with Pool(processes=impparallel) as importpool:
          multiple_results = [importpool.apply_async(verify_data, (tbldata,impuser,imppass,impserver,impport,impcharset,impdatabase,improwchunk,expdatabase)) for tbldata in listofdata]
          print([res.get(timeout=10000) for res in multiple_results])

       impconnection = pymysql.connect(user=impuser,
                                        password=imppass,
                                        host=impserver,
                                        port=int(impport),
                                        charset=impcharset,
                                        database=impdatabase)
       #recreate_fkeys()
       #create_sequences()

    except (Exception, pymysql.Error) as error:
       logging.error ("\033[1;31;40mimport_data: Error while fetching data from MariaDB", str(error))
   
    finally:
       if(impconnection):
          curimptbl.close()
          impconnection.close()
          logging.error("\033[1;37;40mMariaDB import connections are closed")

#procedure to spool data to a file in parallel
def spool_data(tbldata,expuser,exppass,expserver,expport,expcharset,expdatabase,exprowchunk,expmaxrowsperfile):
    global totalproc
    try:
       spconnection=pymysql.connect(user=expuser,
                        password=exppass,
                        host=expserver,
                        port=int(expport),
                        charset=expcharset,
                        database=expdatabase)
   
       spcursor=spconnection.cursor()
       logging.info("Spooling data to \033[1;34;40m"+expdatabase+"/"+tbldata+".csv.gz")
       
       f=gzip.open(expdatabase+"/"+tbldata+".csv.gz","wt")
       spcursor.execute("select * from "+tbldata)
       totalproc+=1
       i=0
       rowcount=0
       fileno=0
       while True:
          i+=1
          records = spcursor.fetchmany(int(exprowchunk)) 
          if not records:
             break 
          cpy = prepare_text(records)
          if (i==1):
             fields=""
             for col in spcursor.description:
                 fields+=col[0]+'\t'
             cpy.seek(0)

          f.write(fields[:-1]+'\n')
          rowcount+=int(exprowchunk)
          if rowcount>=expmaxrowsperfile:
             if (f):
                f.close()
             fileno+=1
             f=gzip.open(expdatabase+"/"+tbldata+"."+str(fileno)+".csv.gz","wt") 
             rowcount=0
          f.write(cpy.getvalue())
          if fileno>0:
             logging.info("*****Written not more than \033[1;33;40m"+str(i*int(exprowchunk))+"\033[0;37;40m rows to a file \033[1;34;40m"+expdatabase+"/"+tbldata+"."+str(fileno)+".csv.gz")
          else:
             logging.info("*****Written not more than \033[1;33;40m"+str(i*int(exprowchunk))+"\033[0;37;40m rows to a file \033[1;34;40m"+expdatabase+"/"+tbldata+".csv.gz")
       f.close()

       rowcount=0
       for thedumpfile in glob.glob(expdatabase+"/"+tbldata+".csv.gz"):
          rowcount+=rawincount(thedumpfile)-1

       for thedumpfile in glob.glob(expdatabase+"/"+tbldata+".*.csv.gz"):
          rowcount+=rawincount(thedumpfile)-1
       
       if (rowcount==-1):
          rowcount=0

       logging.info("Total no of rows exported from table \033[1;34;40m"+tbldata+"\033[0;37;40m = \033[1;36;40m"+str(rowcount))

       if totalproc!=0:
          totalproc-=totalproc

    except (Exception, pymysql.Error) as logerr:
       logging.error("\033[1;31;40mError occured: "+str(logerr))
    finally:
       if(spconnection):
          spcursor.close()
          spconnection.close()
          logging.warning("\033[1;37;40mMariaDB spool data connections are closed")

def runquery(query,qconn,**kwargs):
    global afile
    try:
       label=kwargs.get('label',None)
       if (label!=None):
          afile.write("======================="+label+"=========================\n") 
       curobj=qconn.cursor()
       curobj.execute(query)
       rows=curobj.fetchall()
       totalcols=len(curobj.description)
      
       colnames=",".join([desc[0] for desc in curobj.description])
       afile.write(str(colnames)+"\n")
      
       for row in rows:
          rowline=""
          for col in range(totalcols):
             rowline+=str(row[col])+","
          afile.write(str(rowline[:-1])+"\n")

       curobj.close()
       if (label!=None):
          afile.write("\n\n")

    except (Exception,configparser.Error) as error:
       logging.error('\033[1;31;40mrunquery: Error occured: '+str(error))
       pass

#procedure to get all information from information_schema
def get_all_info():
    global afile
    aserver = read_config('export','servername')
    aport = read_config('export','port')
    adatabase = read_config('export','database')
    acharset = read_config('export','charset')
    auser=input('Enter admin username :')
    apass=getpass.getpass('Enter Password for '+auser+' :')
   
    if test_connection(auser,apass,aserver,aport,acharset,adatabase)==1:
       logging.error("\033[1;31;40mSorry, user: \033[1;36;40m"+auser+"\033[1;31;40m not available or password was wrong!!")
       sys.exit(2)

    logging.info("Gathering information from information_schema")
    try:
       aconn = pymysql.connect(user=auser,
                                password=apass,
                                host=aserver,
                                port=int(aport),
                                charset=acharset,
                                database="information_schema")

       acursor=aconn.cursor()
       acursor.execute("SHOW TABLES")
       rows=acursor.fetchall()
       for row in rows:
           afile=open(adatabase+"/"+crallinfo+"_"+row[0]+".csv", 'wt')
           logging.info("Spooling data "+row[0]+" to a file "+crallinfo+"_"+row[0]+".csv")
           runquery("select * from "+row[0],aconn,label=row[0])
           afile.close()
       
    except (Exception,configparser.Error) as error:
       logging.error('\033[1;31;40mget_all_info: Error occured: '+str(error))
       pass
    finally:
       if (aconn):
          aconn.close()

#procedure to analyze the source database
def analyze_source_database():
    global afile
    aserver = read_config('export','servername')
    aport = read_config('export','port')
    adatabase = read_config('export','database')
    acharset = read_config('export','charset')
    logging.info("Gathering information from server: "+aserver+":"+aport+" database: "+adatabase)
    auser=input('Enter admin username :')
    apass=getpass.getpass('Enter Password for '+auser+' :')
   
    if test_connection(auser,apass,aserver,aport,acharset,adatabase)==1:
       logging.error("\033[1;31;40mSorry, user: \033[1;36;40m"+auser+"\033[1;31;40m not available or password was wrong!!")
       sys.exit(2)

    logging.info("Gathering information from database "+adatabase)
    try:
       aconn = pymysql.connect(user=auser,
                                password=apass,
                                host=aserver,
                                port=int(aport),
                                charset=acharset,
                                database=adatabase)

       afile=open(adatabase+"/"+cranalyzedbfilename+"_"+adatabase+".csv", 'wt')

       afile.write("\nPlugins\n")
       runquery(sqlanalyzeplugin,aconn)
       afile.write("\nTables information\n")
       runquery(sqlanalyzetableinfo.format(adatabase),aconn)
       afile.write("\nStored Procedures and Functions information\n")
       runquery(sqlanalyzeprocfuncinfo.format(adatabase),aconn)

       afile.close()
       logging.info("Gathered information has been stored to "+adatabase+"/"+cranalyzedbfilename+"_"+adatabase+".csv")
       
    except (Exception,configparser.Error) as error:
       logging.error('\033[1;31;40manalyze_source_database: Error occured: '+str(error))
       pass
    finally:
       if (aconn):
          aconn.close()

#procedure to export data
def export_data():
    global exptables,config,configfile,curtblinfo,crtblfile,expmaxrowsperfile,expdatabase,dtnow,expconnection,expcharset
    #Read configuration from mysqlconfig.ini file
    logging.debug("Read configuration from mysqlconfig.ini file")

    expserver = read_config('export','servername')
    expport = read_config('export','port')
    expuser = read_config('export','username')
    expdatabase = read_config('export','database')
    expcharset = read_config('export','charset')
 
    #Create directory to spool all export files
    try:
       #directory name is source databasename
       os.mkdir(expdatabase, 0o755 )
    except FileExistsError as exists:
       pass
    except Exception as logerr:
       logging.error("\033[1;31;40mError occured :"+str(logerr))
       sys.exit(2)

    exprowchunk = read_config('export','rowchunk')
    expparallel = int(read_config('export','parallel'))
    expmaxrowsperfile = int(read_config('export','maxrowsperfile'))
    exppass = read_config('export','password')
    if (exppass==''):
       exppass=' ';
    exppass=decode_password(exppass)

    while test_connection(expuser,exppass,expserver,expport,expcharset,expdatabase)==1:
       exppass=getpass.getpass('Enter Password for '+expuser+' :')
    obfuscatedpass=encode_password(exppass)
    config.set("export","password",obfuscatedpass)
    with open(configfile, 'w') as cfgfile:
       config.write(cfgfile)

    exptables = read_config('export','tables')

    dtnow=datetime.datetime.now()
    logging.info("Exporting Data from Database: "+expdatabase+" Start Date:"+dtnow.strftime("%d-%m-%Y %H:%M:%S"))
    try:
       expconnection = pymysql.connect(user=expuser,
                                        password=exppass,
                                        host=expserver,
                                        port=int(expport),
                                        charset=expcharset,
                                        database=expdatabase)

    except (Exception, pymysql.Error) as logerr:
       logging.error("\033[1;31;40mexport_data: Error occured: "+str(logerr))
       sys.exit()

    global sqllisttables,sqltablesizes
    try: 

       curtblinfo = expconnection.cursor()
       
       #generate_create_fkey()
       #generate_create_okey()
       generate_create_sequence()
       generate_create_trigger()
       generate_create_view()
       generate_create_proc_and_func()


       curtblinfo.execute(sqltableinfo.format(expdatabase))

       tblinforows=curtblinfo.fetchall()

       listoftables=[]
       totalsize=0
       for tblinforow in tblinforows:
           if exptables=="all":
              totalsize+=tblinforow[1] 
              listoftables.append(tblinforow[0])
           else:
              selectedtbls=exptables.split(",")
              for selectedtbl in selectedtbls:
                  if selectedtbl!=tblinforow[0]:
                     continue
                  else:
                     totalsize+=tblinforow[1] 
                     listoftables.append(tblinforow[0])
                     
       
       crtblfile = open(expdatabase+"/"+crtblfilename,"w")

       for tbldata in listoftables:
           logging.info("Generating create table "+tbldata+" script...")
           generate_create_table(tbldata)

       if (crtblfile):
          crtblfile.close()

       if mode=="script":
          if(curtblinfo): curtblinfo.close()
          sys.exit()

       global totalproc

       with Pool(processes=expparallel) as exportpool:
          multiple_results = [exportpool.apply_async(spool_data, (tbldata,expuser,exppass,expserver,expport,expcharset,expdatabase,exprowchunk,expmaxrowsperfile)) for tbldata in listoftables]
          print([res.get(timeout=1000) for res in multiple_results])
   
    except (Exception, pymysql.Error) as error :
       logging.error("\033[1;31;40mexport_data: Error while fetching data from MariaDB", str(error))
   
    finally:
       if(expconnection):
          curtblinfo.close()
          expconnection.close()
          logging.info("\033[1;37;40mMariaDB export connections are closed")

#Main program
def main():
    #initiate signal handler, it will capture if user press ctrl+c key, the program will terminate
    handler = signal.signal(signal.SIGINT, trap_signal)
    try:
       opts, args = getopt.getopt(sys.argv[1:], "heisvl:da", ["help", "export","import","script","log=","dbinfo","allinfo"])
    except getopt.GetoptError as err:
       logging.error("\033[1;31;40mError occured: "+err) # will print something like "option -a not recognized"
       usage()
       sys.exit(2)

    global mode
    global impconnection
    global config,configfile
    verbose = False
    #default log level value
    loglevel="INFO"
    
    #Manipulate options
    for o, a in opts:
        if o == "-v":
            verbose = True
        elif o in ("-h", "--help"):
            usage()
            sys.exit()
        elif o in ("-e", "--export"):
            mode = "export"
        elif o in ("-i", "--import"):
            mode = "import"
        elif o in ("-s", "--script"):
            mode = "script"
        elif o in ("-l", "--log"):
            loglevel = a
        elif o in ("-d", "--dbinfo"):
            mode = "dbinfo"
        elif o in ("-a", "--all-info"):
            mode = "allinfo"
        else:
            assert False, "unhandled option"
  
    if mode==None:
       usage()
       sys.exit(2)

    try: 
       configfile='mysqlconfig.ini'
       logfilename='expimpmysql.log'
       dtnow=datetime.datetime.now()
       nlevel=getattr(logging,loglevel.upper(),None)

       datefrmt = "\033[1;37;40m%(asctime)-15s \033[1;32;40m%(message)s \033[1;37;40m"
       logging.basicConfig(level=nlevel,format=datefrmt,handlers=[logging.FileHandler(logfilename),logging.StreamHandler()])
       logging.info(dtnow.strftime("Starting program %d-%m-%Y %H:%M:%S"))

       if not isinstance(nlevel, int):
          raise ValueError('Invalid log level: %s' % loglevel)

       if not os.path.isfile(configfile):
          logging.error('\033[1;31;40mFile '+configfile+' doesnt exist!') 
          sys.exit(2)

       config = configparser.ConfigParser()
       config.read(configfile)

       if mode=="import":
          logging.info("Importing data......")
          import_data()
       elif mode=="export":
          logging.info("Exporting data......")
          export_data()
       elif mode=="script":
          logging.info("Generating database scripts......")
          export_data()
       elif mode=="dbinfo":
          logging.info("Generating database information......")
          analyze_source_database()
       elif mode=="allinfo":
          logging.info("Gathering All information belongs to this schema/database......")
          get_all_info()
       else:
          sys.exit()

    except Exception as error:
       logging.error("\033[1;31;40mmain: Error occurs: "+str(error))
    
   
   
if __name__ == "__main__":
      main()
