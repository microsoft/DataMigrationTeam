/***This Artifact belongs to the Data SQL Ninja Engineering Team***/
--Created by Bram Pahlawanto
--Initial Version 22-May-2018
--$Id: get_objects_ddl.sql 176 2019-07-01 04:04:13Z bpahlawa $
--$Date: 2019-07-01 14:04:13 +1000 (Mon, 01 Jul 2019) $
--$Author: bpahlawa $
--$Rev: 176 $

set lines 200
set serveroutput on size 1000000
declare
   parobjects varchar(1000):=upper('&OBJECTLIST');
   schemaname varchar(30):=upper('&SCHEMANAME');
   object varchar(80);
   retval number(1);
   outputfile varchar2(100);
   i number:=1;
   dirpath varchar2(300);


   function GET_SCHEMA_DDL(P_SCHEMA_NAME varchar2, P_OBJECT_TYPE varchar2 default 'OBJECT_GRANT', P_OBJNAME_EXPR varchar2 default null,P_DIRNAME varchar2 default null, P_FILENAME varchar2 default null)
   return number
   IS
      m_lines sys.dbms_debug_vc2coll := sys.dbms_debug_vc2coll();   
      SCHEMA_NAME varchar2(100);
      DIRCNT      number;
      DIR_NAME    varchar2(100);
      FHANDLE     UTL_FILE.FILE_TYPE;
      OUTFILENAME varchar(80);
      m_hl        number;
      v_ddls      sys.ku$_ddls;
      v_ddl       sys.ku$_ddl;
      t_hl        number;
      i           number;
      j           number:=1000;
      k           number;
   begin
       SCHEMA_NAME:=upper(P_SCHEMA_NAME);
   
       --check directory
       select count(*) into DIRCNT from dba_directories where directory_name=P_DIRNAME;
       if DIRCNT=0 then
          DIR_NAME:='DATA_PUMP_DIR';
       else
          DIR_NAME:=P_DIRNAME;
       end if;

       --if filename is specified then open a file for write bytes, by default display only 
       if (P_FILENAME is null) then
          OUTFILENAME:=P_OBJECT_TYPE || '_output.sql';
       else
          OUTFILENAME:=P_FILENAME;
       END IF;

       FHANDLE:=UTL_FILE.FOPEN(DIR_NAME,OUTFILENAME,'WB');
   
   	--set some properies
       dbms_metadata.set_transform_param (dbms_metadata.session_transform, 'PRETTY', true);
       dbms_metadata.set_transform_param (dbms_metadata.session_transform,'TABLESPACE',false);
   
       --Initiate metadata retrieval on particular P_OBJECT_TYPE
       m_hl:=DBMS_METADATA.OPEN(object_type=>upper(P_OBJECT_TYPE));
       t_hl := DBMS_METADATA.ADD_TRANSFORM(m_hl, 'DDL');
   
   	--If it is related to object grant then, retrieve metadata object grants from the grantor
       if (upper(P_OBJECT_TYPE)='OBJECT_GRANT') then
          if (SCHEMA_NAME is not null) then
              DBMS_METADATA.SET_FILTER(m_hl,'GRANTOR',SCHEMA_NAME);
   	   end if;
   	--if it is user then get the "create user" metadata
       elsif (upper(P_OBJECT_TYPE)='USER') then
   	   --if schema_name is a regular expression then "create user" metadata can be retrieved fromm other users in the database as well
          if ( NVL(LENGTH(REGEXP_SUBSTR(SCHEMA_NAME,'(in \(|%)',1,1)),0)>0) then
   	       DBMS_METADATA.SET_FILTER(m_hl,'NAME_EXPR',SCHEMA_NAME);
   	   --if NOT then it will be schema level, therefore "create user" metadata for current schema only
          elsif (SCHEMA_NAME is not null) then
              DBMS_METADATA.SET_FILTER(m_hl,'NAME',SCHEMA_NAME);
          end if;
   	--other object's metadata will be retrieved here, for complete list of what objects, please see oracle doc
       ELSE
   	   --Retrieve specific objects from the list of schema that match regular expression below
          if ( NVL(LENGTH(REGEXP_SUBSTR(SCHEMA_NAME,'(in \(|%)',1,1)),0)>0) then
   	       DBMS_METADATA.SET_FILTER(m_hl,'SCHEMA_EXPR',SCHEMA_NAME);
   	   --Retrieve scpedific objects from schema that has been specified in the parameter
          elsif (SCHEMA_NAME is not null) then	
              DBMS_METADATA.SET_FILTER(m_hl, 'SCHEMA', SCHEMA_NAME );
          END if;
       END IF;
       
   	--retrieve object's metadata that match regular expression
       if ( NVL(LENGTH(REGEXP_SUBSTR(P_OBJNAME_EXPR,'(in \(|%)',1,1)),0)>0) then
           DBMS_METADATA.SET_FILTER(m_hl, 'NAME_EXPR', P_OBJNAME_EXPR);
       end if;
   
   	--Let's fetch ddl in CLOB format, the v_ddls will be nested table of clob
       v_ddls:=DBMS_METADATA.fetch_ddl(m_hl);
   
   
   WHILE (v_ddls IS NOT NULL)
   LOOP
       --loop through 1 up to number of v_ddls
       FOR indx IN 1 .. v_ddls.COUNT
       LOOP
   	    --set the value of v_ddl from array of v_ddls, then iterate it
           v_ddl := v_ddls(indx);
   		--check wether the clob has grater than the j value which was set 1000 in the declare section
           if (dbms_lob.getlength(v_ddl.ddlText)>j) then
   	       --manipulate big CLOB into smallerer chunks (so it will fit varchar2, hence can be displayed through sqlplus)
   	       k := ceil(dbms_lob.getlength(v_ddl.ddlText)/j);
               m_lines.extend(k); 
               for i in 1..k 
               loop
                   m_lines(i):= dbms_lob.substr( v_ddl.ddlText, j, 1 + j * ( i - 1 ) );
   	           if (i=k) then
   	              --if end of line then put ; and lienfeed
   	              UTL_FILE.PUT_RAW(FHANDLE,utl_raw.cast_to_raw(m_lines(i) || ';' || chr(10)),TRUE);
   	           else
   	              --otherwise spool it without extra chars
   		      UTL_FILE.PUT_RAW(FHANDLE,utl_raw.cast_to_raw(m_lines(i)),TRUE);
   		   end if;
    	       end loop;
   	   else
               UTL_FILE.PUT_RAW(FHANDLE,utl_raw.cast_to_raw(v_ddl.ddlText || ';' || chr(10)),TRUE);
   	   end if;
       END LOOP;
   	--Flush to a file occasionally
       if (OUTFILENAME is not null) then
           UTL_FILE.FFLUSH(FHANDLE);
       end if;
   	--Fetch another one until it becomes NULL
       v_ddls := DBMS_METADATA.FETCH_DDL(m_hl);
   END LOOP;
   DBMS_METADATA.CLOSE (m_hl);
   
       --if the file is opened then close
       IF UTL_FILE.IS_OPEN(FHANDLE) THEN
          UTL_FILE.FCLOSE (FHANDLE);
       END IF;
       return 0;
   	
   EXCEPTION	
      --standard and stackable error messages
      when others then
         Dbms_Output.put_line ( DBMS_UTILITY.FORMAT_ERROR_STACK() );
         Dbms_Output.put_line ( DBMS_UTILITY.FORMAT_ERROR_BACKTRACE() );
         return 1;
   end;
begin
   select directory_path into dirpath from dba_directories where directory_name='DATA_PUMP_DIR';   
   while (regexp_substr(parobjects,'[^,]+', 1,i) is not null)
   LOOP
       object:=regexp_substr(parobjects,'[^,]+', 1,i);
       outputfile:=object || '_output.sql';
       retval:=get_schema_ddl(p_schema_name=>schemaname,p_object_type=>object,p_filename=>outputfile);
       if (retval=0)
       then
          Dbms_Output.put_line ('Outputfile ' || dirpath || outputfile || ' has been generated successfully!');
       else
          Dbms_Output.put_line ('Unable to generate Outputfile ' || dirpath || outputfile || '!');
       end if;
       i:=i+1;
   END LOOP;
end;
/
