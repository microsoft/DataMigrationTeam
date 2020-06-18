#!/bin/bash
# $Id: installora2pg.sh 255 2020-03-24 06:34:25Z bpahlawa $
# Created 20-AUG-2019
# $Author: bpahlawa $
# $Date: 2020-03-24 17:34:25 +1100 (Tue, 24 Mar 2020) $
# $Revision: 255 $


ORA2PG_GIT="https://github.com/darold/ora2pg.git"
DBD_ORACLE="https://www.cpan.org/modules/by-module/DBD"
PGSQLREPO="https://yum.postgresql.org/repopackages.php"
PGVER="11"
INSTCLIENTKEYWORD="instantclient"
TMPFILE=/tmp/$0.$$

# User specific environment and startup programs
REDFONT="\e[01;48;5;234;38;5;196m"
GREENFONT="\e[01;38;5;46m"
NORMALFONT="\e[0m"
BLUEFONT="\e[01;38;5;14m"
YELLOWFONT="\e[0;34;2;10m"

trap exitshell SIGINT SIGTERM


[[ "$1" != "" ]] && export PGVER="$1"

exitshell()
{
   echo -e "${NORMALFONT}Cancelling script....exiting....."
   exit 0
}

get_rhel_ver()
{
   [[ ! -f /etc/redhat-release ]] && echo "This is not Redhat/Centos distro, exiting...." && exit 1
   export RHELVER=`cat /etc/redhat-release | sed "s/.* \([0-9]\)\..*/\1/"`
}

yum_install()
{
   echo -e "${BLUEFONT}Checking $1 command....."
   [[ $(yum list installed | grep "^${1}" | wc -l) -eq 0 ]] && echo -e "${YELLOWFONT}installing ${1}....${NORMALFONT}" && yum -y install "${1}" && [[ $? -ne 0 ]] && exit 1
   echo -e "${GREENFONT}$1 command is available......"
}


check_internet_conn()
{
   yum update all
   yum_install which
   echo -e "${BLUEFONT}Checking ping command....."
   which ping 2>&1>/dev/null
   [[ $? -ne 0 ]] && yum_install iputils
   echo -e "${GREENFONT}ping command is available....."
   echo -e "${BLUEFONT}Checking internet connection in progress....."
   ping -w2 -c2 www.google.com 2>&1>/dev/null
   [[ $? -ne 0 ]] && echo -e "${REDFONT}Unable to connect to the internet!!, please chreck your connection${NORMALFONT}" && exit 1
   echo -e "${GREENFONT}Internet connection is available${NORMALFONT}"
   yum_install wget
   yum_install curl
   yum_install git
   yum_install perl-open
   yum_install perl-version
   yum_install perl-ExtUtils-MakeMaker
   yum_install perl-DBI
   yum_install perl-Test-Simple
   yum_install libaio-devel
   yum_install make
   yum_install gcc
   yum_install libnsl
   yum_install libaio
   curl -kS --verbose --header 'Host:' $ORA2PG_GIT 2> $TMPFILE
   export GITHOST=`cat $TMPFILE | sed -n -e "s/\(.*CN=\)\([a-z0-9A-Z\.]\+\)\(,.*\|$\)/\2/p"`
   export GITIP=`ping -c1 -w1 github.com | sed -n -e "s/\(.*(\)\([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\)\().*\)/\2/p"`
   rm -f $TMPFILE

}

install_dbd_postgres()
{
   echo -e "${BLUEFONT}Finding pg_config, if it has multiple pg_config then latest version will be used"
   PGCONFIGS=`find / -name "pg_config" | grep pgsql-${PGVER}`

   if [ "$PGCONFIGS" = "" ]
   then
      echo -e "${REDFONT}Postgres client or server is not installed..."
      echo -e "${BLUEFONT}if you want to install postgresql library for ora2pg then press ctrl+C to cancel this installation"
      echo -e "after that, Install postgresql client then re-run this installation!\n"
      echo -e "${YELLOWFONT}However, the ora2pg will be installed without postgresql library"
      echo -e "${GREENFONT}Sleeping for 5 seconds waiting for you to decide...\n\n"
      sleep 5
      echo -e "${BLUEFONT}Installing ora2pg without Postgresql Library........"
      return 0
   fi

   VER=0
   for PGCFG in $PGCONFIGS
   do
      echo -e "${BLUEFONT}Running $PGCFG to get the PostgreSQL version..."
      if [ $VER -lt `$PGCFG | grep VERSION | sed "s/\(.* \)\([0-9]\+\).*$/\2/g"` ]
      then  
         VER=`$PGCFG | grep VERSION | sed "s/\(.* \)\([0-9]\+\).*$/\2/g"` 
         PGCONFIG="$PGCFG"
      fi
   done
   echo -e "${GREENFONT}The latest PostgreSQL Version is $VER"
      
   export POSTGRES_HOME=${PGCONFIG%/*/*}
   echo -e "${BLUEFONT}Checking DBD-Pg latest version...."
   DBDFILE=`curl -kS "${DBD_ORACLE}/" | grep "DBD-Pg-.*tar.gz" | tail -1 | sed -n 's/\(.*="\)\(DBD.*gz\)\(".*\)/\2/p'`
   [[ ! -f ${DBDFILE} ]] && echo -e "${YELLOWFONT}Downloading DBD-Pg latest version...." && wget --no-check-certificate ${DBD_ORACLE}/${DBDFILE}
   echo -e "${BLUEFONT}Checking postgres development...."
   PGLIBS=`yum list installed | grep "postgresql.*libs" | tail -1 | awk '{print $1}'`
   if [ "$PGLIBS" = "" ]
   then
      echo -e "${REDFONT}PostgreSQL Libs doesnt exists......Skipping postgresql library installation..${NORMALFONT}"
      return 0
   else
      yum_install $(echo $PGLIBS | sed 's/libs/devel/g')
   fi
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
   DBDFILE=`curl -kS "${DBD_ORACLE}/" | grep "DBD-Oracle.*tar.gz" | tail -1 | sed -n 's/\(.*="\)\(DBD.*gz\)\(".*\)/\2/p'`
   [[ ! -f ${DBDFILE} ]] && echo -e "${YELLOWFONT}Downloading DBD-Oracle latest version...." && wget --no-check-certificate ${DBD_ORACLE}/${DBDFILE}
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
   echo -e "\n${GREENFONT}ora2pg has been compiled successfully\n"
   cd ..
   [[ -d ora2pg ]] && echo -e "${YELLOWFONT}Removing ora2pg source directory" && rm -rf ora2pg
   [[ -d "${DBDSOURCE}" ]] && echo -e "${YELLOWFONT}Removing ${DBDSOURCE} source directory and gz file${NORMALFONT}" && rm -rf "${DBDSOURCE}"*
   [[ -d "${DBDPGSOURCE}" ]] && echo -e "${YELLOWFONT}Removing ${DBDPGSOURCE} source directory and gz file${NORMALFONT}" && rm -rf "${DBDPGSOURCE}"*

}

install_pgclient()
{
   get_rhel_ver
   PGCLIENT=`curl -kS "${PGSQLREPO}" | grep "EL-${RHELVER}-x86_64" | grep -v "non-free" | tail -1 | sed -n 's/\(.*="\)\(https.*rpm\)\(".*\)/\2/p'`
   rpm -ivh $PGCLIENT
   [[ $RHELVER -ge 8 ]] && yum -y module disable postgresql
   yum -y install postgresql${PGVER}
   
}

install_additional_libs()
{
   get_rhel_ver
   if [ "${RHELVER}" = "6" ]
   then
      yum install -y perl-Time-modules perl-Time-HiRes
   fi
}
   

checking_ora2pg()
{
   echo -e "\n${BLUEFONT}Checking whether ora2pg can be run successfully!!"
   echo -e "Running ora2pg without parameter.........\n"
   echo -e "${YELLOWFONT}This ora2pg will depend on the following ORACLE_HOME directory:${GREENFONT} $ORACLE_HOME"
   if [ "$POSTGRES_HOME" != "" ] 
   then
      echo -e "${YELLOWFONT}This ora2pg will depend on the following POSTGRES_HOME directory:${GREENFONT} $POSTGRES_HOME\n"
   else
      echo -e "${BLUEFONT}This ora2pg is not linked to POSTGRES_HOME due to the unavailability of postgresql client/server package"
      echo -e "${BLUEFONT}You can install postgresql client/server package using dnf or yum REDHAT tool, and re-run this installation at anytime...\n"
   fi
   
   if [ "$SUDO_USER" = "" ]
   then
      echo -e "${YELLOWFONT}\nYou are running this script as ${BLUEFONT}root"
    
      printf "Which Linux username who will run ora2pg tool? : $ERRCODE ";read THEUSER
      [[ "$THEUSER" = "" ]] && THEUSER=empty
      id $THEUSER 2>/dev/null
      while [ $? -ne 0 ] 
      do
          ERRCODE="Sorry!!, User : $THEUSER doesnt exist!!.. try again.."
          printf "Which user that will run this ora2pg tool? : $ERRCODE ";read THEUSER
          [[ "$THEUSER" = "" ]] && THEUSER=empty
          id $THEUSER 2>/dev/null
      done
      printf "User : $THEUSER is available....\n"
      HOMEDIR=`su - $THEUSER -c "echo ~"`
   else
      echo -e "${YELLOWFONT}\nYou are running this script as ${BLUEFONT}$SUDO_USER"
      echo -e "\nUser : $SUDO_USER is running this installation, now setting up necessary environment variable"
      HOMEDIR=`su - $SUDO_USER -c "echo ~"`
      THEUSER="$SUDO_USER"
   fi
   [[ -f $HOMEDIR/.bash_profile ]] && [[ `cat $HOMEDIR/.bash_profile | grep LD_LIBRARY_PATH | wc -l` -eq 0 ]] && echo "export LD_LIBRARY_PATH=$ORACLE_HOME/lib" >> $HOMEDIR/.bash_profile
   
   export PATH=/usr/local/bin:$PATH
   ORA2PGBIN=`which ora2pg`

   if [ "$THEUSER" = "root" ]
   then
      RESULT=`$ORA2PGBIN 2>&1`
   else
      RESULT=`su - $THEUSER -c "$ORA2PGBIN" 2>&1`
      if [ $? -ne 0 ]
      then
         CHECKERROR=`su - $THEUSER -c "$ORA2PGBIN 2>&1 | grep \"Can't locate\" | sed \"s/.*contains: \(.*\) \.).*$/\1/g\""`
         for THEDIR in $CHECKERROR
         do
            [[ -d $THEDIR ]] && echo "setting read and executable permission on PERL lib directory $THEDIR" && chmod o+rx $THEDIR
         done
      fi
   fi
   if [ $? -ne 0 ]
   then
      if [[ $RESULT =~ ORA- ]]
      then
          echo -e "${GREENFONT}ora2pg can be run successfully, however the ${REDFONT}ORA- error ${GREENFONT}could be related to the following issues:"
          echo -e "ora2pg.conf has wrong configuration, listener is not up or database is down!!"          
          echo -e "This installation is considered to be successfull...${NORMALFONT}\n"
          echo -e "\nPlease logout from this user, then login as $THEUSER to run ora2pg...\n"
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
      RESULT=`su - $THEUSER -c "$ORA2PGBIN" 2>&1`
      if [ $? -ne 0 ]
      then
          if [[ $RESULT =~ ORA- ]]
          then
              echo -e "${GREENFONT}ora2pg can be run successfully, however ${REDFONT}the ORA- error ${GREENFONT}could be related to the following issues:"
              echo -e "ora2pg.conf has wrong configuration, listener is not up or database is down!!"          
              echo -e "This installation is considered to be successfull...${NORMALFONT}\n"
              echo -e "\nPlease logout from this user, then login as $THEUSER to run ora2pg...\n"
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
      INSTCLIENTFILE=`find . -name "*${INSTCLIENTKEYWORD}*" -print -quit | grep -v sdk`
      if [[ "$INSTCLIENTFILE" = "" ]]
      then
         echo -e "${REDFONT}Oracle instant client file doesnt exist.... please download from Oracle website.."
         echo -e "This installation requires 2 Oracle instant client files: basic and sdk ${NORMALFONT}"
      else
         echo -e "${REDFONT}Oracle instant client file $INSTCLIENTFILE has been found.... but it is not for linux, please download the correct file!..${NORMALFONT}"
      fi
      exit 1
   else
      yum_install unzip
      INSTCLIENTSDKFILE=`find . -name "*${INSTCLIENTKEYWORD}*sdk*linux*" -print -quit`
      if [[ "$INSTCLIENTSDKFILE" = "" ]]
      then
         INSTCLIENTSDKFILE=`find . -name "*${INSTCLIENTKEYWORD}*sdk*" -print -quit`
         if [[ "$INSTCLIENTSDKFILE" = "" ]]
         then
             echo -e "${REDFONT}Oracle instant client sdk file doesnt exist.... please download from Oracle website.."
             echo -e "This installation requires 2 Oracle instant client files: basic and sdk ${NORMALFONT}"
         else
             echo -e "${REDFONT}Oracle instant client sdk file $INSTCLIENTSDKFILE has been found.... but not for linux, please download the correct file!....${NORMALFONT}"
         fi
         exit 1
      else
         unzip -o $INSTCLIENTSDKFILE -d /usr/local
         [[ $? -ne 0 ]] && echo -e "${REDFONT}Unzipping file $INSTCLIENTSDKFILE failed!!${NORMALFONT}" && exit 1
      fi
      unzip -o $INSTCLIENTFILE -d /usr/local
      [[ $? -ne 0 ]] && echo -e "${REDFONT}Unzipping file $INSTCLIENTFILE failed!!${NORMALFONT}" && exit 1
      echo -e "${GREENFONT}File $INSTCLIENTFILE has been unzipped successfully!!"
      LIBFILE=`find /usr/local -name "libclntsh.so*" 2>/dev/null| grep -Ev "stage|inventory" | tail -1 2>/dev/null`
      export ORACLE_HOME="${LIBFILE%/*}"
   fi
}

   [[ $(whoami) != "root" ]] && echo -e "${REDFONT}This script must be run as root or with sudo...${NORMALFONT}" && exit 1
   check_internet_conn
   echo -e "${BLUEFONT}Checking oracle installation locally....."

   echo -e "${BLUEFONT}Checking ORACLE_HOME environment variable...."
   if [ "$ORACLE_HOME" != "" ]
   then
      if [ ! -d $ORACLE_HOME ]
      then
         echo -e "${BLUEFONT}The $ORACLE_HOME is not a directory, so searchig from root directory / ...."
         LIBFILE=`find / -name "libclntsh.so*" 2>/dev/null| grep -Ev "stage|inventory" | tail -1 2>/dev/null`
      else
         LIBFILE=`find $ORACLE_HOME -name "libclntsh.so*" 2>/dev/null| grep -Ev "stage|inventory" | tail -1 2>/dev/null`
      fi
   else
      LIBFILE=`find / -name "libclntsh.so*" 2>/dev/null| grep -Ev "stage|inventory" | tail -1 2>/dev/null`
   fi
   if [ "$LIBFILE" = "" ]
   then
      echo -e "${BLUEFONT}oracle instantclient needs to be installed or $ORACLE_HOME is not correct"
      install_oracle_instantclient
   else
      if [[ $LIBFILE =~ .*${INSTCLIENTKEYWORD}.*$ ]]
      then
         export ORACLE_HOME="${LIBFILE%/*}"
      else
         export ORACLE_HOME="${LIBFILE%/*/*}"
      fi
   fi
   install_additional_libs
   install_dbd_oracle
   install_pgclient
   install_dbd_postgres
   install_ora2pg
   checking_ora2pg
