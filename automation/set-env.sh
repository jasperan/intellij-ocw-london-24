#!/bin/bash
# Copyright (c) 2021 Oracle and/or its affiliates. All rights reserved.

################################################################################
#
# Name: .set-env.sh
#
# Description: Script to load basic Livelabs environment variables
#
#
#  Pre-requisite: None.
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
################################################################################

PRIVATE_IP=$(cat /etc/hosts | grep $(hostname) | grep -v grep |tail -1 | awk '{print $1}')
HOSTNAME=$(hostname)

if [ -z ${PRIVATE_IP} ]; then
  PRIVATE_IP=$(oci-metadata -g privateIp | sed -n -e 's/^.*Private IP address: //p')
fi

export PRIVATE_IP
export PUBLIC_IP=$(curl -s ifconfig.me)

load_basic() {
  #
  ###############################################################################
  # Display Info
  # -----------------------------------------------------------------------------
  clear
  echo "================================================================================"
  figlet -c Oracle LiveLabs
  echo "================================================================================"
  echo "                       ENV VARIABLES                                            "
  echo "--------------------------------------------------------------------------------"
  echo " . PRIVATE_IP          = ${PRIVATE_IP}"
  echo " . PUBLIC_IP           = ${PUBLIC_IP}"
  echo " . HOSTNAME            = ${HOSTNAME}"
  echo "--------------------------------------------------------------------------------"
  echo "================================================================================"

}
# Aliases
alias lh='ls -ltrh'

if [ -f /etc/oratab ] || [ -f /var/opt/oracle/oratab ]; then
  oratab_exist=Y
else
  oratab_exist=N
fi

case ${oratab_exist} in
Y)
  if [ -z ${ORACLE_SID} ]; then
    load_basic
    echo "                       Database ENV is not set                                  "
    echo "                                                                                "
    echo " Run this to reload/setup the Database ENV: source /usr/local/bin/.set-env-db.sh"
    echo "--------------------------------------------------------------------------------"
    echo "================================================================================"
    echo " "
  else
    . ~/.set-env-db.sh ${ORACLE_SID}
  fi
  ;;
*)
  load_basic
  echo " "
  ;;
esac
