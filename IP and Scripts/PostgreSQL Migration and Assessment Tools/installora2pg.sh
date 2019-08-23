#!/bin/bash
# $Id: installora2pg.sh 189 2019-08-23 02:06:12Z bpahlawa $
# Created 20-AUG-2019
# $Author: bpahlawa $
# $Date: 2019-08-23 12:06:12 +1000 (Fri, 23 Aug 2019) $
# $Revision: 189 $


ORA2PG_GIT="https://github.com/darold/ora2pg.git"
DBD_ORACLE="https://www.cpan.org/modules/by-module/DBD"
INSTCLIENTKEYWORD="instantclient"
TMPFILE=/tmp/$0.$$

# User specific environment and startup programs
REDFONT="\e[01;48;5;234;38;5;196m"
GREENFONT="\e[01;38;5;46m"
NORMALFONT="\e[0m"
BLUEFONT="\e[01;38;5;14m"
YELLOWFONT="\e[01;38;5;226m"

trap exitshell SIGINT SIGTERM

exitshell()
{
   echo -e "${NORMALFONT}Cancelling script....exiting....."
   exit 0
}

yum_install()
{
   echo -e "${BLUEFONT}Checking $1 command....."
   [[ $(yum list installed | grep "^${1}" | wc -l) -eq 0 ]] && echo -e "${YELLOWFONT}installing ${1}...." && yum -y install "${1}" && [[ $? -ne 0 ]] && exit 1
   echo -e "${GREENFONT}$1 command is available......"
}


check_internet_conn()
{
   yum update all
   yum_install which
   echo -e "${BLUEFONT}Checking ping command....."
   which ping 2>&1>/dev/null
   [[ $? -ne 0 ]] && echo -e "${REDFONT}Unable to find command ping${NORMALFONT}" && exit 1
   echo -e "${GREENFONT}ping command is available....."
   echo -e "${BLUEFONT}Checking internet connection in progress....."
   ping -w2 -c2 www.google.com 2>&1>/dev/null
   [[ $? -ne 0 ]] && echo -e "${REDFONT}Unable to connect to the internet!!, please chreck your connection${NORMALFONT}" && exit 1
   echo -e "${GREENFONT}Internet connection is available"
   yum_install wget
   yum_install curl
   yum_install git
   yum_install perl-ExtUtils-MakeMaker
   yum_install perl-DBI
   yum_install make
   yum_install gcc
   curl -S --verbose --header 'Host:' $ORA2PG_GIT 2> $TMPFILE
   export GITHOST=`cat $TMPFILE | sed -n -e "s/\(.*CN=\)\([a-z0-9A-Z\.]\+\)\(,.*\)/\2/p"`
   export GITIP=`ping -c1 -w1 github.com | sed -n -e "s/\(.*(\)\([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\)\().*\)/\2/p"`
   rm -f $TMPFILE

}

install_dbd_postgres()
{
   echo -e "${BLUEFONT}Finding pg_config, if it has multiple pg_config, then only the last one will be taken"
   PGCONFIG=`find / -name "pg_config" | tail -1` 

   if [ "$PGCONFIG" = "" ]
   then
      echo -e "${REDFONT}Postgres client or server is not installed..."
      echo -e "${BLUEFONT}if you want to install postgresql library for ora2pg then press ctrl+C to cancel this instllation"
      echo -e "after that, Install postgresql client then re-run this installation!\n"
      echo -e "${YELLOWFONT}However, the ora2pg will be installed without postgresql library"
      echo -e "${GREENFONT}Sleeping for 5 seconds waiting for you to decide...\n\n"
      sleep 5
      echo -e "${BLUEFONT}Installing ora2pg without Postgresql Library........"
      return 0
   fi
      
   export POSTGRES_HOME=${PGCONFIG%/*/*}
   echo -e "${BLUEFONT}Checking DBD-Pg latest version...."
   DBDFILE=`curl -S ${DBD_ORACLE}/ | grep "DBD-Pg-.*tar.gz" | tail -1 | sed -n 's/\(.*="\)\(DBD.*gz\)\(".*\)/\2/p'`
   [[ ! -f ${DBDFILE} ]] && echo -e "${YELLOWFONT}Downloading DBD-Pg latest version...." && wget ${DBD_ORACLE}/${DBDFILE}
   echo -e "${GREENFONT}Extracting $DBDFILE${NORMALFONT}"
   tar xvfz ${DBDFILE}
   cd ${DBDFILE%.*.*}
   perl Makefile.PL
   if [ -f Makefile ]
   then
      echo -e "${YELLOWFONT}Compiling $DBDFILE${NORMALFONT}"
      make
      make install
      [[ $? -ne 0 ]] && echo -e "${REDFONT}Error in compiling ${DBDFILE%.*.*} ${NORMALFONT}" && exit 1
   fi
   cd ..
   export DBDPGSOURCE="${DBDFILE%.*.*}"
}


install_dbd_oracle()
{
   echo -e "${BLUEFONT}Checking DBD-Oracle latest version...."
   DBDFILE=`curl -S ${DBD_ORACLE}/ | grep "DBD-Oracle.*tar.gz" | tail -1 | sed -n 's/\(.*="\)\(DBD.*gz\)\(".*\)/\2/p'`
   [[ ! -f ${DBDFILE} ]] && echo -e "${YELLOWFONT}Downloading DBD-Oracle latest version...." && wget ${DBD_ORACLE}/${DBDFILE}
   echo -e "${GREENFONT}Extracting $DBDFILE${NORMALFONT}"
   tar xvfz ${DBDFILE}
   cd ${DBDFILE%.*.*}
   perl Makefile.PL
   if [ -f Makefile ]
   then
      echo -e "${YELLOWFONT}Compiling $DBDFILE${NORMALFONT}"
      make
      make install
      [[ $? -ne 0 ]] && echo -e "${REDFONT}Error in compiling ${DBDFILE%.*.*} ${NORMALFONT}" && exit 1
   fi
   cd ..
   export DBDSOURCE="${DBDFILE%.*.*}"
}


install_ora2pg()
{
   if [ "$GITHOST" = "github.com" ]
   then
      echo -e "${YELLOWFONT}Cloning git repository..."
      git clone $ORA2PG_GIT
   else
      echo -e "${REDFONT}Server in github.com ssl certificate is different!!, Hostname=$GITHOST ${NORMALFONT}"
      echo -e "can not continue!!, there must be something wrong...."
      echo -e "GitIP $GITIP"
      exit 1
   fi
   cd ora2pg
   perl Makefile.PL
   if [ -f Makefile ]
   then
      echo -e "${YELLOFONT}Compiling ora2pg${NORMALFONT}"
      make
      make install
      [[ $? -ne 0 ]] && echo -e "${REDFONT}Error in compiling ora2pg...${NORMALFONT}" && exit 1
   fi
   echo -e "\n${GREENFONT}ora2pg compiled successfully\n"
   cd ..
   [[ -d ora2pg ]] && echo -e "${YELLOWFONT}Removing ora2pg source directory" && rm -rf ora2pg
   [[ -d "${DBDSOURCE}" ]] && echo -e "${YELLOWFONT}Removing ${DBDSOURCE} source directory and gz file${NORMALFONT}" && rm -rf "${DBDSOURCE}"*
   [[ -d "${DBDPGSOURCE}" ]] && echo -e "${YELLOWFONT}Removing ${DBDPGSOURCE} source directory and gz file${NORMALFONT}" && rm -rf "${DBDPGSOURCE}"*

}


checking_ora2pg()
{
   echo -e "${BLUEFONT}Checking whether ora2pg can be run successfully!!"
   echo -e "Running ora2pg without parameter........."
   RESULT=`ora2pg 2>&1`
   if [ $? -ne 0 ]
   then
      if [[ $RESULT =~ ORA- ]]
      then
          echo -e "${GREENFONT}ora2pg can be run successfully, however it could have the following issues:"
          echo -e "ora2pg.conf has wrong entry, listener is not up or database is down!!"          
          echo -e "This installation is considered to be successfull...${NORMALFONT}"
          exit 0
      fi
      if [[ $RESULT =~ .*find.*configuration.*file ]]
      then
          echo -e "${GREENFONT}ora2pg requires ora2pg.conf...."
          echo -e "ora2pg has been installed successfully${NORMALFONT}"
          exit 0
      fi
      echo -e "${REDFONT}There some issues with ora2pg....${NORMALFONT}"
      echo -e "Usually this is due to LD_LIBRARY_PATH that was not set...."
      echo -e "${BLUEFONT}Enforcing LD_LIBRARY_PATH to $ORACLE_HOME/lib"
      export LD_LIBRARY_PATH=$ORACLE_HOME/lib
      echo -e "${YELLOWFONT}Re-running ora2pg......"
      RESULT=`ora2pg 2>&1`
      if [ $? -ne 0 ]
      then
          if [[ $RESULT =~ ORA- ]]
          then
              echo -e "${GREENFONT}ora2pg can be run successfully, however it could have the following issues:"
              echo -e "ora2pg.conf has wrong entry, listener is not up or database is down!!"          
              echo -e "This installation is considered to be successfull...${NORMALFONT}"
              exit 0
          else
              echo -e "${REDFONT}The issues are not resolved, please check logfile....!!${NORMALFONT}"
              exit 1
          fi
      fi
   fi
   echo -e "${GREENFONT}ora2pg can be run successfully"
   echo -e "${NORMALFONT}Before running ora2pg you must do:"
   echo -e "export LD_LIBRARY_PATH=\$ORACLE_HOME/lib"
}

install_oracle_instantclient()
{
   echo -e "${YELLOWFONT}Installing oracle instant client"
   echo -e "${YELLOWFONT}Finding instantclient filename with keyword=${INSTCLIENTKEYWORD}"
   INSTCLIENTFILE=`find . -name "*${INSTCLIENTKEYWORD}*linux*" -print -quit | grep -v sdk`
   if [[ "$INSTCLIENTFILE" = "" ]]
   then
      echo -e "${REDFONT}Oracle instant client file doesnt exist.... please download from oracle website..${NORMALFONT}"
      exit 1
   else
      yum_install unzip
      INSTCLIENTSDKFILE=`find . -name "*${INSTCLIENTKEYWORD}*sdk*linux*" -print -quit`
      if [[ "$INSTCLIENTSDKFILE" = "" ]]
      then
         echo -e "${REDFONT}Oracle instant client sdk file doesnt exist.... please download from oracle website..${NORMALFONT}"
         exit 1
      else
         unzip -o $INSTCLIENTSDKFILE -d /usr/local
         [[ $? -ne 0 ]] && echo -e "${REDFONT}Unzipping file $INSTCLIENTSDKFILE failed!!${NORMALFONT}" && exit 1
      fi
      unzip -o $INSTCLIENTFILE -d /usr/local
      [[ $? -ne 0 ]] && echo -e "${REDFONT}Unzipping file $INSTCLIENTFILE failed!!${NORMALFONT}" && exit 1
      echo -e "${GREENFONT}File $INSTCLIENTFILE has been unzipped successfully!!"
      LIBFILE=`find /usr/local -name "libclntsh.so*" | grep -Ev "stage|inventory" | tail -1 2>/dev/null`
      export ORACLE_HOME="${LIBFILE%/*}"
   fi
}
   check_internet_conn
   echo -e "${BLUEFONT}Checking oracle installation locally....."
   LIBFILE=`find / -name "libclntsh.so*" | grep -Ev "stage|inventory" | tail -1 2>/dev/null`
   if [ "$LIBFILE" = "" ]
   then
      echo -e "${BLUEFONT}oracle instantclient needs to be installed"
      install_oracle_instantclient
   else
      if [[ $LIBFILE =~ .*${INSTCLIENTKEYWORD}.*$ ]]
      then
         export ORACLE_HOME="${LIBFILE%/*}"
      else
         export ORACLE_HOME="${LIBFILE%/*/*}"
      fi
   fi
   install_dbd_oracle
   install_dbd_postgres
   install_ora2pg
   checking_ora2pg

