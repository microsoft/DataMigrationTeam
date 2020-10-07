#/***This Artifact belongs to the Data SQL Ninja Engineering Team***/
#!/bin/bash
# $Id: comparedb.sh 159 2019-03-24 15:52:12Z bpahlawa $
# Created 05-MAR-2019
# $Author: bpahlawa $
# $Date: 2019-03-25 02:52:12 +1100 (Mon, 25 Mar 2019) $
# $Revision: 159 $

#Reset config file
RECONFIG="$1"

#config file of this program (hidden)
CONFIGFILE=.configpg

#if the parameter is reconfigure then remove .configpg file
[[ "$RECONFIG" = "reconfigure" ]] && rm -f $CONFIGFILE

#Temp source output file
SOURCEOUTPUT=sourceoutput.txt

#Temp destination output file
DESTOUTPUT=destoutput.txt

#Source SALT for password encryption
SOURCESALT=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

#Destination SALT for password encryption
DESTSALT=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

#Capture all stored procedures in this file
ALLPROC=allprocs


#Run psql on source instace
function run_psql_source()
{
  COMMAND="$1"
  echo "Executing Query on database=$SOURCEDB Server=$SOURCEHOST"
  export PGPASSWORD=$(echo $SOURCEPASS | openssl enc -aes-256-cbc -pass "pass:$SOURCESALT" -a -d)
  psql -P "pager=off" -P "format=unaligned" -F "," -U "$SOURCEUSER" -w -h $SOURCEHOST -p $SOURCEPORT -c "$COMMAND" -d "$SOURCEDB" -o $SOURCEOUTPUT
  [[ $? -ne 0 ]] && echo "USER $SOURCEUSER doesnt exist or has Invalid password !!, please try again!!" && exit 1
  unset PGPASSWORD
}

#Run psql on destination instace
function run_psql_dest()
{
  COMMAND="$1"
  echo "Executing Query on database=$DESTDB Server=$DESTHOST"
  export PGPASSWORD=$(echo $DESTPASS | openssl enc -aes-256-cbc -pass "pass:$DESTSALT" -a -d)
  psql -P "pager=off" -P "format=unaligned" -F "," -U "$DESTUSER" -w -h $DESTHOST -p $DESTPORT -c "$COMMAND" -d "$DESTDB" -o $DESTOUTPUT
  [[ $? -ne 0 ]] && echo "USER $DESTUSER doesnt exist or has Invalid password !!, please try again!!" && exit 1
  unset PGPASSWORD
}

#Retrieve destination config
function get_dest_config()
{
     echo -n "Please enter Destination Server Name                        : "; read -a DESTHOST
     [[ "$DESTHOST" != "" ]] && echo "DESTHOST=$DESTHOST" >> $CONFIGFILE || echo "Unable to get Destination DB information, skipping.." || return
     echo -n "Please enter Destination Database post (default=5432)       : "; read -a DESTPORT
     [[ "$DESTPORT" = "" ]] && echo "DESTPORT=5432" >> $CONFIGFILE || echo "DESTPORT=$DESTPORT" >> $CONFIGFILE
     echo -n "Please enter Destination Database's user (default=postgres) : "; read -a DESTUSER
     [[ "$DESTUSER" = "" ]] && echo "DESTUSER=postgres" >> $CONFIGFILE || echo "DESTUSER=$DESTUSER" >> $CONFIGFILE
}

#Retrieve source config
function get_source_config()
{
  #if configile exists
  if [ -f $CONFIGFILE ]
  then
     #Retrieve the following information from CONFIGFILE
     SOURCEHOST=$(grep "^SOURCEHOST" $CONFIGFILE | cut -f2 -d=)
     SOURCEPORT=$(grep "^SOURCEPORT" $CONFIGFILE | cut -f2 -d=)
     SOURCEUSER=$(grep "^SOURCEUSER" $CONFIGFILE | cut -f2 -d=)
     SOURCEDB=$(grep "^SOURCEDB" $CONFIGFILE | cut -f2 -d=)

     [[ "$SOURCEHOST" = "" || "$SOURCEPORT" = "" || "$SOURCEUSER" = "" ]] && echo "Config file has empty variables, please delete $CONFIGFILE and re-run this script!!" && exit 1

     #Check if the DESTHOST exists
     if [ `grep "^DESTHOST" $CONFIGFILE | wc -l` -ne 0 ]
     then
        #Retrieve destination host's config
        DESTHOST=$(grep "^DESTHOST" $CONFIGFILE | cut -f2 -d=)
        DESTPORT=$(grep "^DESTPORT" $CONFIGFILE | cut -f2 -d=)
        DESTDB=$(grep "^DESTDB" $CONFIGFILE | cut -f2 -d=)
        DESTUSER=$(grep "^DESTUSER" $CONFIGFILE | cut -f2 -d=)
     fi
  else
     #config file doesnt exists therefore create one
     touch $CONFIGFILE
     #Capture the following information
     [[ $? -ne 0 ]] && echo "Unable to write config file in this directory, exiting... " && exit 1
     echo -n "Please enter Source Server Name (default=localhost)         : "; read -a SOURCEHOST
     [[ "$SOURCEHOST" = "" ]] && echo "SOURCEHOST=localhost" >> $CONFIGFILE || echo "SOURCEHOST=$SOURCEHOST" >> $CONFIGFILE
     echo -n "Please enter Source Database post (default=5432)            : "; read -a SOURCEPORT
     [[ "$SOURCEPORT" = "" ]] && echo "SOURCEPORT=5432" >> $CONFIGFILE || echo "SOURCEPORT=$SOURCEPORT" >> $CONFIGFILE
     echo -n "Please enter Source Database's user (default=postgres)      : "; read -a SOURCEUSER
     [[ "$SOURCEUSER" = "" ]] && echo "SOURCEUSER=postgres" >> $CONFIGFILE || echo "SOURCEUSER=$SOURCEUSER" >> $CONFIGFILE
     echo -n "Are you comparing 2 Database ? (default=n)                  : "; read -a ANS
     [[ "$ANS" = "" ]] && ANS="n"
     if [ "$ANS" = "y" ]
     then
         get_dest_config
     fi
  fi

}

#Spool stored procedure source codes to a file ALLPROC_SOURCEDB
function spool_proc()
{
   local OUTPUTFILE="$1"
   local COMMAND=""
   local TMPOUT="$0.tmp.$$"
   export PGPASSWORD=$(echo $SOURCEPASS | openssl enc -aes-256-cbc -pass "pass:$SOURCESALT" -a -d)
   echo "Executing Query on database=$SOURCEDB Server=$SOURCEHOST"
   > ${ALLPROC}_${SOURCEDB}.sql

   for PROCNAME in `cat $OUTPUTFILE | sed '/^([0-9]\+ row.*)/d' | cut -f1-2 -d, | grep -v proname`
   do
      echo "$PROCNAME" >> ${ALLPROC}_${SOURCEDB}.sql
      echo ">>>spooling out procedure $PROCNAME"
      COMMAND="select prosrc from pg_catalog.pg_proc where proname='$PROCNAME';"
      psql -t -P "pager=off" -P "format=unaligned" -U "$SOURCEUSER" -w -h $SOURCEHOST -p $SOURCEPORT -c "$COMMAND" -d "$SOURCEDB" -o $TMPOUT
      if [ $? -ne 0 ]
      then
         echo "USER $SOURCEPASS doesnt exist or has Invalid password !!, please try again!!"
         return
      else
         cat $TMPOUT | sed "/^([0-9]\+ row.*)/d" >> ${ALLPROC}_${SOURCEDB}.sql
         echo -e "\n" >> ${ALLPROC}_${SOURCEDB}.sql
      fi
   done
   unset PGPASSWORD
   rm -f $TMPOUT
}

#List source databases
function list_source_db()
{
  echo -e "\nDisplaying list of source databases to choose"
  local COMMAND="select datname from pg_catalog.pg_database where datname not like 'temp%';"
  export PGPASSWORD=$(echo $SOURCEPASS | openssl enc -aes-256-cbc -pass "pass:$SOURCESALT" -a -d)

  #Run psql command on source with all SOURCE variable details
  ALLSOURCEDB=`psql -P "pager=off" -P "format=unaligned" -F "," -U "$SOURCEUSER" -w -h $SOURCEHOST -p $SOURCEPORT -c "$COMMAND" | sed '/^([0-9]\+ rows)/d' | grep -v datname`
  unset PGPASSWORD
  if [ "$DESTDB" != "" ]
  then
     echo "$ALLSOURCEDB"
     echo -e "\nEnter database name: "; read SOURCEDB
  fi

}

#List destination databases
function list_dest_db()
{
  echo -e "\nDisplaying list of destination databases to choose"
  local COMMAND="select datname from pg_catalog.pg_database where datname not like 'temp%';"
  export PGPASSWORD=$(echo $DESTPASS | openssl enc -aes-256-cbc -pass "pass:$DESTSALT" -a -d)

  #Run psql command on source with all SOURCE variable details
  psql -P "pager=off" -P "format=unaligned" -F "," -U "$DESTUSER" -w -h $DESTHOST -p $DESTPORT -c "$COMMAND" -d postgres| sed '/^([0-9]\+ rows)/d' | grep -v datname
  unset PGPASSWORD
  echo -e "\nEnter database name: "; read DESTDB
}

#Main

which psql 2>/dev/null 1>/dev/null

[[ $? -ne 0 ]] && echo "Unable to find psql, please login as a postgresql database's user!!" && exit 1

#create a config file
get_source_config

#Retrieve a config file
get_source_config

#Get the password
echo "Please enter the PASSWORD for USER=${SOURCEUSER} SERVER=${SOURCEHOST}"
read -s SOURCEPASS
export SOURCEPASS=$(echo $SOURCEPASS | openssl enc -aes-256-cbc -pass "pass:$SOURCESALT" -a -e)
echo "Obfuscating password , result: $SOURCEPASS"
list_source_db

#check if destination host is empty, if not then retrieve destination host information
if [ "$DESTHOST" != "" ]
then
   echo "Please enter the PASSWORD for USER=${DESTUSER} SERVER=${DESTHOST}"
   read -s DESTPASS
   export DESTPASS=$(echo $DESTPASS | openssl enc -aes-256-cbc -pass "pass:$DESTSALT" -a -e)
   echo "Obfuscating password , result: $DESTPASS"
   echo "Gathering information from Database $SOURCEDB and $DESTDB ....."
   list_dest_db
else
   echo "Gathering Database $SOURCEDB information....."
fi


#List of all queries
declare -A QUERIES=(
["tableinfo"]="select table_schema,table_name,table_type,user_defined_type_catalog,user_defined_type_schema,user_defined_type_name from information_schema.tables where table_schema not in ('pg_catalog','information_schema','sys','dbo') order by 2,1,4,3;"
["procinfo"]="SELECT p.proname AS procedure_name,p.pronargs AS num_args,t1.typname AS return_type,l.lanname AS language_type FROM pg_catalog.pg_proc p
LEFT JOIN pg_catalog.pg_type t1 ON p.prorettype=t1.oid
LEFT JOIN pg_catalog.pg_language l ON p.prolang=l.oid
JOIN pg_catalog.pg_authid a ON p.proowner=a.oid
where rolname not in ('pg_catalog','information_schema','sys','dbo')
order by 1,4;"
["extension"]="select extname,nspname namespace from pg_catalog.pg_extension e LEFT JOIN pg_namespace n ON e.extnamespace=n.oid order by 2,1;"
["language"]="select lanname from pg_catalog.pg_language order by 1;"
["usedfeat"]="SELECT  rolname,proname,lanname,proname,typname
FROM    pg_catalog.pg_namespace n
JOIN    pg_catalog.pg_authid a ON nspowner = a.oid
JOIN    pg_catalog.pg_proc p ON pronamespace = n.oid
JOIN    pg_catalog.pg_type t ON typnamespace = n.oid
JOIN    pg_catalog.pg_language l on prolang = l.oid where nspname in (select schema_name from information_schema.schemata
where schema_name not in ('pg_catalog','information_schema','sys','dbo'));"
)

if [ "$DESTHOST" = "" ]
then
for SOURCEDB in $ALLSOURCEDB
do
   for Q in "${!QUERIES[@]}"
   do
      echo "Gathering $Q information"
      run_psql_source "${QUERIES[$Q]}"
      cp -p $SOURCEOUTPUT src_output_${SOURCEDB}_${Q}.csv
   done
   rm -f $SOURCEOUTPUT
   spool_proc src_output_${SOURCEDB}_usedfeat.csv
done
else
   for Q in "${!QUERIES[@]}"
   do
      echo "Gathering $Q information"
      run_psql_source "${QUERIES[$Q]}"
      run_psql_dest "${QUERIES[$Q]}"
      grep -vf $DESTOUTPUT $SOURCEOUTPUT | sed '/^([0-9]\+ rows)/d' >diff_output_${Q}.csv
      cp -p $SOURCEOUTPUT src_output_${SOURCEDB}_${Q}.csv
      cp -p $DESTOUTPUT dst_output_${DESTDB}_${Q}.csv
  done
  rm -f $SOURCEOUTPUT
  rm -f $DESTOUTPUT
  spool_proc src_output_${SOURCEDB}_usedfeat.csv
fi
