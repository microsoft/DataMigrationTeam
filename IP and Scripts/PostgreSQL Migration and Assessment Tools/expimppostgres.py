#/***This Artifact belongs to the Data SQL Ninja Engineering Team***/
#!/bin/python36
# $Id: expimppostgres.py 167 2019-04-04 01:23:19Z bpahlawa $
# Created 05-MAR-2019
# $Author: bpahlawa $
# $Date: 2019-04-04 12:23:19 +1100 (Thu, 04 Apr 2019) $
# $Revision: 167 $

import re
from string import *
import psycopg2
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
#create analyze db report
cranalyzedbfilename='analyzedb'

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
       user_defined_type_catalog,
       user_defined_type_schema,
       user_defined_type_name 
from information_schema.tables 
where table_schema not in ('pg_catalog','information_schema','sys','dbo') order by 2,1,4,3;
"""

sqlanalyzeprocinfo="""
SELECT p.proname AS procedure_name,p.pronargs AS num_args,t1.typname AS return_type,l.lanname AS language_type FROM pg_catalog.pg_proc p
LEFT JOIN pg_catalog.pg_type t1 ON p.prorettype=t1.oid
LEFT JOIN pg_catalog.pg_language l ON p.prolang=l.oid
JOIN pg_catalog.pg_authid a ON p.proowner=a.oid
where rolname not in ('pg_catalog','information_schema','sys','dbo')
order by 1,4
"""

sqlanalyzeextension="select extname,nspname namespace from pg_catalog.pg_extension e LEFT JOIN pg_namespace n ON e.extnamespace=n.oid order by 2,1"
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
sqlcreatetrigger="""
select 'create trigger ' || trigger_schema || '.' || trigger_name || ' ' || action_timing || ' ' || action_statement
from information_schema.triggers
"""

#Set parameters
sqlsetparameters="""
SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET row_security = off;
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

#SQL Statement for creating sequences v10 or later only
#this query is specifically for v10, because the earlier version doesnt have pg_sequence table
sqlcreatesequencev10="""
select 'CREATE SEQUENCE ' || nspname || '.' || relname || ' as ' || typname ||
       ' START WITH ' || seqstart || ' INCREMENT BY ' || seqincrement || ' NO MINVALUE NO MAXVALUE CACHE ' || seqcache || ';' as result,
       'select pg_catalog.currval(''' || nspname || '.' || relname || ''');' as result2
from pg_sequence s 
JOIN pg_class c ON s.seqrelid = c.oid
JOIN pg_type t ON s.seqtypid=t.oid
JOIN pg_authid a ON c.relowner = a.oid
JOIN pg_namespace n ON nspowner=a.oid and c.relnamespace=n.oid
where nspname not in ('pg_catalog','information_schema','sys','dbo')
"""

#SQL Statement for creating sequence v9.6 or earlier
sqlcreatesequence="""
select 'CREATE SEQUENCE ' || sequence_schema || '.' || sequence_name ||
       ' START WITH ' || start_value || ' INCREMENT BY ' || increment || ' NO MINVALUE ' || 'NO MAXVALUE CACHE 1;' as result,
       'SELECT last_value from ' || sequence_schema || '.' || sequence_name || ';' as cmd2run,
       'SELECT pg_catalog.setval(''' || sequence_schema || '.' || sequence_name || ''',##CURSEQ##,True);' as result2
from information_schema.sequences
where sequence_schema not in ('pg_catalog','information_schema','sys','dbo')
"""

#SQL Statement for creating tables
sqlcreatetable="""
 SELECT                                          
  'CREATE TABLE ' || nspname || '.' || relname || E'
  (
  ' ||
  array_to_string(
    array_agg(
      '    ' || column_name || ' ' ||  type || ' '|| not_null
    )
    , E',
  '
  ) || E'
  );
'
from
(
SELECT
    c.relname, n.nspname as nspname, 
    (case when a.attname=word then '"'|| a.attname || '"' else a.attname END) AS column_name,
    pg_catalog.format_type(a.atttypid, a.atttypmod) as type,
    case
      when a.attnotnull
    then 'NOT NULL'
    else 'NULL'
    END as not_null
  FROM pg_class c,
   pg_attribute a,
   pg_type t,
   pg_namespace n,
   (select word,catcode from pg_get_keywords() where catcode in ('T','R')) k
   WHERE c.relname = '{0}'
   AND a.attnum > 0
   AND a.attrelid = c.oid
   AND a.atttypid = t.oid
   and k.word (+) = a.attname
   AND n.oid=c.relnamespace
 ORDER BY a.attnum
) as tabledefinition
group by nspname,relname
"""

#SQL Statement for listing all base tables
sqllisttables="select table_schema,table_name from information_schema.tables where table_schema not in ('pg_catalog','information_schema','sys','dbo') and table_type='BASE TABLE'"

#List name of tables and their sizes
sqltableinfo="select table_schema,table_name,pg_catalog.pg_table_size(table_schema || '.' || table_name)/1024/1024 rowsz from information_schema.tables where table_schema not in ('pg_catalog','information_schema','sys','dbo') and table_type='BASE TABLE'"

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
    return(Crypt(thepass,'bramiscool'))

#procedure to decode password
def decode_password(thepass):
    return(Crypt(thepass,'bramiscool',encrypt=0))

#procedure to read configuration from config.ini file
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
    global curtblinfo,expdatabase
    try:
       curtblinfo.execute(sqlcreatesequence)
       rows=curtblinfo.fetchall()
       fseqfile = open(expdatabase+"/"+crseqfilename,"w")
  
       for row in rows:
          fseqfile.write(row[0]+"\n")
          curtblinfo.execute(row[1])
          currval=curtblinfo.fetchone()[0]
          fseqfile.write(row[2].replace('##CURSEQ##',str(currval))+"\n")

    except Exception as error:
       logging.error('\033[1;31;40mgenerate_create_sequence: Error occured: '+str(error))
       sys.exit(2)
    finally:
       if (fseqfile):
          fseqfile.close() 

#procedure to generate triggers creation script 
def generate_create_trigger():
    global curtblinfo,expdatabase
    try:
       curtblinfo.execute(sqlcreatetrigger)
       rows=curtblinfo.fetchall()
       trigfile = open(expdatabase+"/"+crtrigfilename,"w")
  
       for row in rows:
          trigfile.write(row[0]+"\n")

    except Exception as error:
       logging.error('\033[1;33;40mgenerate_create_trigger: Error occured: '+str(error))
       sys.exit(2)
    finally:
       if (trigfile):
          trigfile.close() 

#procedure to delete foreign key
def delete_fkey():
    global curimptbl,expdatabase,impconnection
    logging.info("Deleting Foreign keys\n")
    sqlcmd=""
    try:
       fkeyfile = open(expdatabase+"/"+crfkeyfilename,"r")
       for sqlraw in fkeyfile.readlines():
          sqlcmd=str.join(" ",sqlraw.replace("ADD","DROP").split(" ")[:6])
          try:
             curimptbl.execute(sqlcmd)

             if sqlcmd=="":
                logging.info("Unable to find foreign keys")
             else:
                logging.info("Foreign Keys have been deleted succesfully")

             impconnection.commit()

          except Exception as error:
             if not str(error).find("does not exist"):
                logging.error('delete_fkey: Error occured: '+str(error))
             else:
                logging.error('\033[1;31;40mdelete_fkey: '+str(error))
             impconnection.rollback()
             pass
       
       if(fkeyfile):
          fkeyfile.close()

    except Exception as error:
       logging.error("\033[1;33;40mdelete_fkey: Error occured: "+str(error))
      
    
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
       curtblinfo.execute(sqlcreatetable.format(tablename))
       rows=curtblinfo.fetchall()

       for row in rows:
          crtblfile.write(row[0])
    
    except (Exception,configparser.Error) as error:
       logging.error('\033[1;33;40mgenerate_create_table: Error occured: '+str(error))
       pass

#procedure to create table
def create_table():
    global impconnection,expdatabase
    curcrtable=impconnection.cursor()
    createtable=""
    logging.info("Creating tables from the script")
    try:
       fcrtable = open(expdatabase+"/"+crtblfilename,"r")
       for line in fcrtable.readlines():
          if line.find(");") != -1:
             try:
                curcrtable.execute(createtable+line)
                impconnection.commit()
             except (Exception,configparser.Error) as error:
                if not str(error).find("already exists"):
                   logging.error('create_table: Error occured: '+str(error))
                else:
                   logging.error("\033[1;31;40m"+str(error))
                impconnection.rollback()
                pass
             createtable=""
          else:
             if createtable=="":
                logging.info("\033[1;33;40mExecuting...."+line)
             createtable+=line

       fcrtable.close()
          
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
             except (Exception,psycopg2.Error) as error:
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
       cpy.write('\t'.join([str(x).replace('False','f').replace('True','t').replace('\n','\\n').replace('\r','\\r').replace('\t','\\t').replace('\\','\\\\') for x in row]) + '\n')
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
def insert_data_from_file(tablefile,impuser,imppass,impserver,impport,impdatabase,improwchunk,dirname):
    try:
       filename=tablefile+".csv.gz"
       tablename=".".join(tablefile.split(".")[0:2])
       
       insconnection=psycopg2.connect(user=impuser,
                                      password=imppass,
                                      host=impserver,
                                      port=impport,
                                      database=impdatabase)

       curinsdata=insconnection.cursor()

       logging.info("Inserting data from \033[1;34;40m"+filename+"\033[1;37;40m to table \033[1;34;40m"+tablename)

       if os.path.isfile(dirname+"/"+filename):
          bigfile = gzip.open(dirname+"/"+filename,"rt")
          bigfile.readline()
       else:
          logging.info("File "+dirname+"/"+filename+" doesnt exist!, so skipping import to table "+tablename)
          insconnection.rollback()
          return()

       curinsdata.execute(sqlsetparameters)
       curinsdata.copy_from(bigfile,tablename,sep='\t',null='None')
       insconnection.commit()

       logging.info("Data from \033[1;34;40m"+dirname+"/"+filename+"\033[1;37;40m has been inserted to table \033[1;34;40m"+tablename+"\033[1;36;40m")
       

    except (Exception,psycopg2.Error) as error:
       print ("insert_data_from_file: Error :"+str(error))

    finally:
       if(bigfile):
          bigfile.close()
       if(insconnection):
          insconnection.commit()
          curinsdata.close()
          insconnection.close()

#verify data
def verify_data(tablename,impuser,imppass,impserver,impport,impdatabase,improwchunk,dirname):
    if len(tablename.split("."))>2:
       return()
    try:
       vrfyconnection=psycopg2.connect(user=impuser,
                                      password=imppass,
                                      host=impserver,
                                      port=impport,
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

       if rowsfromfile==rowsfromtable:
          logging.info("Table \033[1;34;40m"+tablename+"\033[0;37;40m no of rows: \033[1;36;40m"+str(rowsfromfile)+" does match!\033[1;36;40m")
       else:
          logging.info("Table \033[1;34;40m"+tablename+"\033[1;31;40m DOES NOT match\033[1;37;40m")
          logging.info("      Total Rows from \033[1;34;40m"+tablename+" file(s) = \033[1;31;40m"+str(rowsfromfile))
          logging.info("      Total Rows inserted to \033[1;34;40m"+tablename+"  = \033[1;31;40m"+str(rowsfromtable))
       

    except (Exception,psycopg2.Error) as error:
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
    print("   -l, --log=          INFO|DEBUG|WARNING|ERROR|CRITICAL\n")

def test_connection(t_user,t_pass,t_server,t_port,t_database):
    try:
       impconnection = psycopg2.connect(user=t_user,
                                        password=t_pass,
                                        host=t_server,
                                        port=t_port,
                                        database=t_database)

       impconnection.close()
       return(0)
    except (Exception, psycopg2.Error) as logerr:
       if str(logerr).find("connection failed"):   
          print("\033[1;31;40m"+str(logerr))
          return(1)
       else:
          print("\033[1;31;40mError occurred: "+str(logerr))
    

#procedure to import data
def import_data():
    global imptables,config,configfile,curimptbl,expdatabase
    #Loading import configuration from config.ini file
    impserver = read_config('import','servername')
    impport = read_config('import','port')
    impuser = read_config('import','username')
    impdatabase = read_config('import','database')
    expdatabase = read_config('export','database')
    improwchunk = read_config('import','rowchunk')
    impparallel = int(read_config('import','parallel'))
    imppass = read_config('import','password')
    imppass=decode_password(imppass)

    while test_connection(impuser,imppass,impserver,impport,impdatabase)==1:
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
       impconnection = psycopg2.connect(user=impuser,
                                        password=imppass,
                                        host=impserver,
                                        port=impport,
                                        database=impdatabase)

    except (Exception, psycopg2.Error) as logerr:
       logging.error("\033[1;31;40mimport_data: Error: "+str(logerr))
       sys.exit()

    try:
       curimptbl = impconnection.cursor()

       create_table()

       create_table_keys()

       delete_fkey()

       listofdata=[]

       curimptbl.execute(sqllisttables)
       rows = curimptbl.fetchall()
     
       for row in rows:
          if imptables=="all":
              if os.path.isfile(expdatabase+"/"+row[0]+"."+row[1]+".csv.gz"):
                 logging.info("Truncating table \033[1;34;40m"+row[0]+"."+row[1]+"\033[1;37;40m in progress")
                 curimptbl.execute("truncate table "+row[0]+"."+row[1]+" restart identity")
                 curimptbl.execute("truncate table "+row[0]+"."+row[1]+" cascade")
                 listofdata.append(row[0]+"."+row[1])
                 for slicetbl in glob.glob(expdatabase+"/"+row[0]+"."+row[1]+".*.csv.gz"):
                     listofdata.append(slicetbl.split("/")[1].replace(".csv.gz",""))
                    
              else:
                 logging.info("File "+expdatabase+"/"+row[0]+"."+row[1]+".csv.gz doesnt exist")
          else:
              selectedtbls=imptables.split(",")
              for selectedtbl in selectedtbls:
                  if selectedtbl!=row[0]+"."+row[1]:
                     continue
                  else:
                     if os.path.isfile(expdatabase+"/"+row[0]+"."+row[1]+".csv.gz"):
                        logging.info("Truncating table \033[1;34;40m"+row[0]+"."+row[1]+"\033[1;37;40m in progress")
                        curimptbl.execute("truncate table "+row[0]+"."+row[1]+" restart identity")
                        curimptbl.execute("truncate table "+row[0]+"."+row[1]+" cascade")
                        listofdata.append(row[0]+"."+row[1])
                        for slicetbl in glob.glob(expdatabase+"/"+row[0]+"."+row[1]+".*.csv.gz"):
                            listofdata.append(slicetbl.split("/")[1].replace(".csv.gz",""))
                     else:
                        logging.info("File "+expdatabase+"/"+row[0]+"."+row[1]+".csv.gz doesnt exist")

       impconnection.commit()
       impconnection.close()

       with Pool(processes=impparallel) as importpool:
          multiple_results = [importpool.apply_async(insert_data_from_file, (tbldata,impuser,imppass,impserver,impport,impdatabase,improwchunk,expdatabase)) for tbldata in listofdata]
          print([res.get(timeout=1000000) for res in multiple_results])
       
       with Pool(processes=impparallel) as importpool:
          multiple_results = [importpool.apply_async(verify_data, (tbldata,impuser,imppass,impserver,impport,impdatabase,improwchunk,expdatabase)) for tbldata in listofdata]
          print([res.get(timeout=10000) for res in multiple_results])

       impconnection = psycopg2.connect(user=impuser,
                                        password=imppass,
                                        host=impserver,
                                        port=impport,
                                        database=impdatabase)
       recreate_fkeys()
       create_sequences()

    except (Exception, psycopg2.Error) as error:
       logging.error ("\033[1;31;40mimport_data: Error while fetching data from PostgreSQL", str(error))
   
    finally:
       if(impconnection):
          curimptbl.close()
          impconnection.close()
          logging.error("\033[1;37;40mPostgreSQL import connections are closed")

#procedure to spool data to a file in parallel
def spool_data(tbldata,expuser,exppass,expserver,expport,expdatabase,exprowchunk,expmaxrowsperfile):
    global totalproc
    try:
       spconnection=psycopg2.connect(user=expuser,
                        password=exppass,
                        host=expserver,
                        port=expport,
                        database=expdatabase)
   
       spcursor=spconnection.cursor()
       logging.info("Spooling data to \033[1;34;40m"+expdatabase+"/"+tbldata[0]+".csv.gz")
       
       f=gzip.open(expdatabase+"/"+tbldata[0]+".csv.gz","wt")
       f.write(tbldata[1]+"\n")
       spcursor.execute("select * from "+tbldata[0])
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
             cpy.seek(0)

          rowcount+=int(exprowchunk)
          if rowcount>=expmaxrowsperfile:
             if (f):
                f.close()
             fileno+=1
             f=gzip.open(expdatabase+"/"+tbldata[0]+"."+str(fileno)+".csv.gz","wt") 
             f.write(tbldata[1]+"\n")
             rowcount=0
          f.write(cpy.getvalue())
          if fileno>0:
             logging.info("*****Written not more than \033[1;33;40m"+str(i*int(exprowchunk))+"\033[0;37;40m rows to a file \033[1;34;40m"+expdatabase+"/"+tbldata[0]+"."+str(fileno)+".csv.gz")
          else:
             logging.info("*****Written not more than \033[1;33;40m"+str(i*int(exprowchunk))+"\033[0;37;40m rows to a file \033[1;34;40m"+expdatabase+"/"+tbldata[0]+".csv.gz")
       f.close()

       rowcount=0
       for thedumpfile in glob.glob(expdatabase+"/"+tbldata[0]+".csv.gz"):
          rowcount+=rawincount(thedumpfile)-1

       for thedumpfile in glob.glob(expdatabase+"/"+tbldata[0]+".*.csv.gz"):
          rowcount+=rawincount(thedumpfile)-1

       logging.info("Total no of rows exported from table \033[1;34;40m"+tbldata[0]+"\033[0;37;40m = \033[1;36;40m"+str(rowcount))

       if totalproc!=0:
          totalproc-=totalproc

    except (Exception, psycopg2.Error) as logerr:
       logging.error("\033[1;31;40mError occured: "+str(logerr))
    finally:
       if(spconnection):
          spcursor.close()
          spconnection.close()
          logging.warning("\033[1;37;40mPostgreSQL spool data connections are closed")

def runquery(query,qconn):
    global afile
    try:
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

    except (Exception,configparser.Error) as error:
       logging.error('\033[1;31;40mrunquery: Error occured: '+str(error))
       pass

#procedure to analyze the source database
def analyze_source_database():
    global afile
    aserver = read_config('export','servername')
    aport = read_config('export','port')
    adatabase = read_config('export','database')
    logging.info("Gathering information from server: "+aserver+":"+aport+" database: "+adatabase)
    auser=input('Enter admin username :')
    apass=getpass.getpass('Enter Password for '+auser+' :')
   
    if test_connection(auser,apass,aserver,aport,adatabase)==1:
       logging.error("\033[1;31;40mSorry, user: \033[1;36;40m"+auser+"\033[1;31;40m not available or password was wrong!!")
       sys.exit(2)

    logging.info("Gathering information from database "+adatabase)
    try:
       aconn = psycopg2.connect(user=auser,
                                password=apass,
                                host=aserver,
                                port=aport,
                                database=adatabase)

       afile=open(adatabase+"/"+cranalyzedbfilename+"_"+adatabase+".csv", 'wt')

       afile.write("\nExtensions\n")
       runquery(sqlanalyzeextension,aconn)
       afile.write("\nTables information\n")
       runquery(sqlanalyzetableinfo,aconn)
       afile.write("\nProgramming language\n")
       runquery(sqlanalyzelanguage,aconn)
       afile.write("\nUsed features\n")
       runquery(sqlanalyzeusedfeature,aconn)
       afile.write("\nStored Procs information\n")
       runquery(sqlanalyzeprocinfo,aconn)

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
    global exptables,config,configfile,curtblinfo,crtblfile,expmaxrowsperfile,expdatabase,dtnow,expconnection
    #Read configuration from config.ini file
    logging.debug("Read configuration from config.ini file")

    expserver = read_config('export','servername')
    expport = read_config('export','port')
    expuser = read_config('export','username')
    expdatabase = read_config('export','database')
 
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
    exppass=decode_password(exppass)

    while test_connection(expuser,exppass,expserver,expport,expdatabase)==1:
       exppass=getpass.getpass('Enter Password for '+expuser+' :')
    obfuscatedpass=encode_password(exppass)
    config.set("export","password",obfuscatedpass)
    with open(configfile, 'w') as cfgfile:
       config.write(cfgfile)

    exptables = read_config('export','tables')

    dtnow=datetime.datetime.now()
    logging.info("Exporting Data to Database: "+expdatabase+" Start Date:"+dtnow.strftime("%d-%m-%Y %H:%M:%S"))
    try:
       expconnection = psycopg2.connect(user=expuser,
                                        password=exppass,
                                        host=expserver,
                                        port=expport,
                                        database=expdatabase)

    except (Exception, psycopg2.Error) as logerr:
       logging.error("\033[1;31;40mexport_data: Error occured: "+str(logerr))
       sys.exit()

    global sqllisttables,sqltablesizes
    try: 

       curtblinfo = expconnection.cursor()
       
       generate_create_fkey()
       generate_create_okey()
       generate_create_sequence()
       #generate_create_trigger()
       if mode=="script":
          curtblinfo.close()
          expconnection.close()
          sys.exit()


       curtblinfo.execute(sqltableinfo)

       tblinforows=curtblinfo.fetchall()

       listoftables=[]
       totalsize=0
       for tblinforow in tblinforows:
           if exptables=="all":
              totalsize+=tblinforow[2] 
              listoftables.append(tblinforow[0]+'.'+tblinforow[1])
           else:
              selectedtbls=exptables.split(",")
              for selectedtbl in selectedtbls:
                  if selectedtbl!=tblinforow[0]+"."+tblinforow[1]:
                     continue
                  else:
                     totalsize+=tblinforow[2] 
                     listoftables.append(tblinforow[0]+'.'+tblinforow[1])
                     
       listofdata=[]
       for tbl in listoftables:
           thequery="""
select (case when column_name=word then '"'|| column_name || '"' else column_name END) AS column_name 
from information_schema.columns c 
LEFT JOIN (select word,catcode from pg_get_keywords() where catcode in ('T','R')) ON word = column_name
where table_schema='{0}' and table_name='{1}' order by ordinal_position
"""
           curtblinfo.execute(thequery.format(tbl.split(".")[0],tbl.split(".")[1]))
           csvcolumns="COPY "+tbl+" ("
           columns=curtblinfo.fetchall()
           for column in columns:
               csvcolumns+=column[0]+','
           listofdata.append((tbl,csvcolumns[:-1]+") FROM stdin WITH NULL 'None';"))

       
       crtblfile = open(expdatabase+"/"+crtblfilename,"w")

       for tbldata in listofdata:
           generate_create_table(tbldata[0].split(".")[1])

       if (crtblfile):
          crtblfile.close()



       global totalproc

       with Pool(processes=expparallel) as exportpool:
          multiple_results = [exportpool.apply_async(spool_data, (tbldata,expuser,exppass,expserver,expport,expdatabase,exprowchunk,expmaxrowsperfile)) for tbldata in listofdata]
          print([res.get(timeout=1000) for res in multiple_results])
   
    except (Exception, psycopg2.Error) as error :
       logging.error("\033[1;31;40mexport_data: Error while fetching data from PostgreSQL", str(error))
   
    finally:
       if(expconnection):
          curtblinfo.close()
          expconnection.close()
          logging.info("\033[1;37;40mPostgreSQL export connections are closed")

#Main program
def main():
    #initiate signal handler, it will capture if user press ctrl+c key, the program will terminate
    handler = signal.signal(signal.SIGINT, trap_signal)
    try:
       opts, args = getopt.getopt(sys.argv[1:], "heisvl:dr", ["help", "export","import","script","log=","dbinfo","rows"])
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
        elif o in ("-r", "--rows"):
            mode = "rowinfo"
        else:
            assert False, "unhandled option"
  
    if mode==None:
       usage()
       sys.exit(2)

    try: 
       configfile='config.ini'
       logfilename='expimppostgresql.log'
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
       elif mode=="rowinfo":
          logging.info("Gathering No of rows......")
          export_data()
       else:
          sys.exit()

    except Exception as error:
       logging.error("\033[1;31;40mmain: Error occurs: "+str(error))
    
   
   
if __name__ == "__main__":
      main()
