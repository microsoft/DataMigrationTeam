/***This Artifact belongs to the Data SQL Ninja Engineering Team***/
Pre-requisites
ora2pg must have been installed and ora2pg.conf is located either on /etc/ora2pg/ora2pg.conf or the same directory as this script

How to use it:
#1 Parameter would be the query that must match the ora2pg configuration TYPE 
#2 Parameter would be the number of objects to be spooled into each file

The query must have the following rule:
first column: must be the name of the object (table, synonym, index, etc)
second column: it is not mandatory, but if it is specified then it will be part of the output filename
first column must use distinct keyword
first where clause should have owner='SCHEMA' (the exact word SCHEMA not to be interpreted as the real schema name)
please ensure SCHEMA is specified in ora2pg.conf

E.g:

splitora2pg.pl "select table_name from dba_tables where owner='SCHEMA'" 100
=> The above command will split the output into many files where each file has 100 objets
splitora2pg.pl "select object_Name,object_type from dba_objects where owner='SCHEMA'" 300

splitora2pg.pl "select object_Name,object_type from dba_objects where owner='SCHEMA'" 300
=> the above command will split the output into many files , however if no distinct keyword is specificed and there are 2 object types
that have the same name then you will get duplicate object_name therefore the second column need to be removed, 
use the following query instead:

splitora2pg.pl "select distinct object_Name from dba_objects where owner='SCHEMA'" 300
=> if TYPE in ora2pg has multiple values then the above result will also create multiple output files with the same contents

