#!/bin/bash
# Copyright (c) 2021 Oracle and/or its affiliates. All rights reserved.

################################################################################
#
# Name:set-env-db.sh
#
# Description: Script to set the database environment (single instance) in multiple
#             Oracle homes setup
#
#
#  Pre-requisite: This should be executed as the user that owns Oracle DB binaries.
#
#  AUTHOR(S)
#  -------
#  Rene Fontcha, Oracle LiveLabs Platform Lead
#
#  MODIFIED        Date                 Comments
#  --------        ----------           -----------------------------------
#  Rene Fontcha    10/18/2021           Initial Creation
#  Rene Fontcha    05/19/2022           Replaced Public IP lookup routine
#  Rene Fontcha    07/19/2022           Added "Oracle LiveLabs" branding banner
#
###############################################################################
PRIVATE_IP=$(cat /etc/hosts | grep $(hostname) | grep -v grep |tail -1 | awk '{print $1}')
HOSTNAME=$(hostname)

if [ -z ${PRIVATE_IP} ]; then
  PRIVATE_IP=$(oci-metadata -g privateIp | sed -n -e 's/^.*Private IP address: //p')
fi

export PRIVATE_IP
export PUBLIC_IP=$(curl -s ifconfig.me)
unset ORACLE_SID

if [ -f /etc/oratab ]; then
  OTAB=/etc/oratab
  oratab_exist=Y
elif [ -f /var/opt/oracle/oratab ]; then
  OTAB=/var/opt/oracle/oratab
  oratab_exist=Y
else
  oratab_exist=N
  echo 'oratab file not found.'
fi
load_env_header() {
  clear
  echo "================================================================================"
  figlet -c Oracle LiveLabs
  echo "================================================================================"
  echo "                       ENV VARIABLES                                            "
  echo "--------------------------------------------------------------------------------"
}

load_db_env() {
  export ORAENV_ASK=NO
  . oraenv >/dev/null
  export ORAENV_ASK=YES
  export OH=${ORACLE_HOME}
  if [ -f ${OH}/bin/orabasehome ]; then
    export ORACLE_BASE_HOME=$(orabasehome)
    export TNS_ADMIN=${ORACLE_BASE_HOME}/network/admin
  else
    export TNS_ADMIN=${OH}/network/admin
  fi
  export LD_LIBRARY_PATH=$OH/lib
  export PATH=${OH}/bin:${OH}/OPatch:${JAVA_HOME}/bin:/bin:/usr/ccs/bin:/usr/sfw/bin:/usr/bin:/usr/sbin:/usr/ucb:/etc:/usr/local/bin:/usr/dt/bin:/usr/openwin/bin:/opt/sfw/bin/:.:~:/sbin:/usr/X11R6/bin:$PATH
  alias ssql="$OH/bin/sql / as sysdba"

  echo " . ORACLE_BASE         = ${ORACLE_BASE}"
  if [ -f ${OH}/bin/orabasehome ]; then
    echo " . ORACLE_BASE_HOME    = ${ORACLE_BASE_HOME}"
  fi
  echo " . ORACLE_HOME         = ${OH}"
  echo " . ORACLE_SID          = ${ORACLE_SID}"
  echo " . PRIVATE_IP          = ${PRIVATE_IP}"
  echo " . PUBLIC_IP           = ${PUBLIC_IP}"
  echo " . HOSTNAME            = ${HOSTNAME}"
  echo "--------------------------------------------------------------------------------"
  echo "                       Database ENV set for ${ORACLE_SID}                       "
  echo "                                                                                "
  echo " Run this to reload/setup the Database ENV: source /usr/local/bin/.set-env-db.sh"
  echo "--------------------------------------------------------------------------------"
  echo "================================================================================"
  echo " "
}
#
#############################################################################
# Display Info
# ---------------------------------------------------------------------------

case ${oratab_exist} in
Y)
  if [ -z $1 ]; then
    SIDLIST=$(egrep -v -e '^$|#|\*' ${OTAB} | cut -f1 -d:)
    echo ""
    echo "List of Database Instances"
    printf "\n%-2s %-15s \n" "#" "ORACLE_SID"
    echo "-- ----------"
    PS3=$'\n'"Select a number from the list (1-n): "
    select sid in ${SIDLIST}; do
      echo ""
      if [ -n $sid ]; then
        ORACLE_SID=$sid
        load_env_header
        load_db_env
        break
      fi
    done
  else
    load_env_header
    if egrep -v '#|\*' ${OTAB} | grep -w "${1}:" >/dev/null; then
      ORACLE_SID=$1
      load_db_env
    else
      echo " . PRIVATE_IP          = ${PRIVATE_IP}"
      echo " . PUBLIC_IP           = ${PUBLIC_IP}"
      echo " . HOSTNAME            = ${HOSTNAME}"
      echo "--------------------------------------------------------------------------------"
      echo "                       Database ENV is not set                                  "
      echo "                       Supplied ORACLE_SID ($1) not found in $OTAB.             "
      echo "                                                                                "
      echo " Run this to reload/setup the Database ENV: source /usr/local/bin/.set-env-db.sh"
      echo "--------------------------------------------------------------------------------"
      echo "================================================================================"
      echo " "
    fi
  fi
  ;;
*)
  load_env_header
  echo " . PRIVATE_IP          = ${PRIVATE_IP}"
  echo " . PUBLIC_IP           = ${PUBLIC_IP}"
  echo " . HOSTNAME            = ${HOSTNAME}"
  echo "--------------------------------------------------------------------------------"
  echo "================================================================================"
  echo " "
  ;;
esac
