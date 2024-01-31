#!/bin/bash
# Copyright (c) 2021 Oracle and/or its affiliates. All rights reserved.

################################################################################
#
# Name:setup-firstboot.sh
#
# Description: Script to configure static hostname enforced via cloud-init
#
#
#  Pre-requisite: This should be executed as "root" user.
#
#  AUTHOR(S)
#  -------
#  Rene Fontcha, Oracle LiveLabs Platform Lead
#
#  MODIFIED        Date                 Comments
#  --------        ----------           ------------------------------------
#  Rene Fontcha    03/29/2022           Initial Creation
#  Rene Fontcha    05/23/2022           Added routine to create "oracle" user
#
###############################################################################
shopt -s extglob
current_s_host=$(hostname -s)
current_l_host=$(hostname)
t_stamp=$(date "+%m-%d-%Y_%H%M%S")
declare -a h_other_aliases

if [[ ${current_l_host} =~ \. ]]; then
  l_host=${current_l_host}
else
  l_host="${current_l_host}.livelabs.oraclevcn.com"
fi

export el_version=$(uname -r | grep -o -P 'el.{0,1}')

if [[ "$el_version" == "el7" ]]; then
  pkg_bin=yum
  echo "Running noVNC Configuration for Enterprise Linux 7 (EL7)"
elif [[ "$el_version" == "el8" ]]; then
  pkg_bin=dnf
  echo "Running noVNC Configuration for Enterprise Linux 8 (EL8)"
else
  echo "Cannot proceed! This script can only be performed on systems with Enterprise Linux 7  or 8"
  exit 1
fi

function yes_or_no() {
  while true; do
    read -p "$* [y/n]: " yn
    case $yn in
    [Yy]*) return 100 ;;
    [Nn]*) return 200 ;;
    esac
  done
}

clear
echo
#yes_or_no "The current host shortname is: ***** ${current_s_host} *****. Do you want to keep this as the permanent static name?"
rt_code=100
echo
if [[ "$rt_code" == 100 ]]; then
  s_host="${current_s_host}"
  h_file_input=$(cat /etc/hosts | grep $(hostname -s) | tail -1 | tr -s ' ' | cut -d ' ' -f2-)
  t_file_input=$(echo ${h_file_input} | sed "s/${l_host}//g;s/${s_host}\S*//g")
  if [[ -z "${h_file_input}" ]]; then
    echo
    echo "/etc/hosts file on this instance does not contain an entry for ${s_host}. It will be added accordingly"
    echo
    if [[ -z ${l_host} ]]; then
      l_host="${s_host}.livelabs.oraclevcn.com"
      h_file_input="${l_host}   ${s_host}"
    elif [[ ${l_host} == "${s_host}.livelabs.oraclevcn.com" ]]; then
      h_file_input="${l_host}   ${s_host}"
    else
      h_file_input="${l_host}   ${s_host}.livelabs.oraclevcn.com   ${s_host}"
    fi
  else #add rewrite of host entry to accommodate existing aliases
    if [[ -z ${l_host} ]]; then
      l_host="${s_host}.livelabs.oraclevcn.com"
      h_file_input=$(echo "${l_host}   ${s_host}  ${t_file_input}")
    elif [[ ${l_host} == "${s_host}.livelabs.oraclevcn.com" ]]; then
      h_file_input=$(echo "${l_host}   ${s_host}  ${t_file_input}")
    else
      h_file_input=$(echo "${l_host}   ${s_host}.livelabs.oraclevcn.com   ${s_host} ${t_file_input}")
    fi
  fi
else
  echo ""
  while true; do
    echo
    echo "*************"
    #read -p 'Please press *ENTER* to accept the default *holserv1* or type in your preferred host shortname (not the FQDN, must be lowercase and alphanumeric). : ' s_host
    echo
    s_host="holserv1"
    if [[ "${s_host}" =~ ^[a-z0-9\-]+$ ]] && [[ ! "${s_host}" =~ ^[0-9]+$ ]]; then
      echo ""
      echo "The host shortname will be set to *** ${s_host} *** across all incarnations of future offsprings from a custom image created from this instance"
      echo
      l_host="${s_host}.livelabs.oraclevcn.com"
      h_file_input="${l_host}   ${s_host}"
      break
    else
      echo ""
      echo "Invalid characters typed. A valid host shortname can only contain alphanumeric characters, hyphens(-)"
      echo "Please Retry"
      echo ""
    fi
  done
fi

#yes_or_no "Do you have additional host alias(es), virtualhost names, or FQDN required for labs that are using this instance?"
rt_code=200
echo

if [[ "$rt_code" == 100 ]]; then
  echo
  echo "Enter each additional host alias, FQDN, or virtualhost name beside ${s_host} and ${l_host} (separated from each other by a space. e.g. serv1 serv1.demo.com)."
  read -a h_other_aliases
  echo
fi
echo

mkdir -p /root/bootstrap
if [[ -f /root/bootstrap/firstboot.sh ]]; then
  cp /root/bootstrap/firstboot.sh /root/bootstrap/firstboot.sh.bak.${t_stamp}
fi

cat >/root/bootstrap/firstboot.sh <<EOF
#!/bin/bash
# Copyright (c) 2021 Oracle and/or its affiliates. All rights reserved.

##################################################################################
#
# Name: "firstboot.sh"
#
# Description:
#   Script to perform one-time adjustment to an OCI instance upon booting for the
#   first time to preserve a static hostname across reboots and adjust any setting
#   specific to a given workshop
#
#  Pre-requisite: This should be executed as "root" user.
#
#  AUTHOR(S)
#  -------
#  Rene Fontcha, Oracle LiveLabs Platform Lead
#
#  MODIFIED        Date                 Comments
#  --------        ----------           -----------------------------------
#  Rene Fontcha    02/17/2021           Initial Creation
#  Rene Fontcha    10/07/2021           Added routine to update livelabs-get_started.sh
#  Rene Fontcha    02/11/2022           Added Google Chrome update
#  Rene Fontcha    03/24/2022           Added support for Oracle Enterprise Linux 8
#
###################################################################################
#
# Generated on $t_stamp
#

# Preserve user configured hostname across instance reboots
sed -i -r 's/^PRESERVE_HOSTINFO.*\$/PRESERVE_HOSTINFO=2/g' /etc/oci-hostname.conf

# Preserve hostname info and set it for current boot
hostnamectl set-hostname ${l_host}

# Add static name to /etc/hosts
echo "\$(oci-metadata -g privateIp |sed -n -e 's/^.*Private IP address: //p')   ${h_file_input} ${h_other_aliases[@]}" >>/etc/hosts

# Update "livelabs-get_started.sh"
rm -rf /tmp/ll_refresh
mkdir -p /tmp/ll_refresh
cd /tmp/ll_refresh
wget -q https://objectstorage.us-ashburn-1.oraclecloud.com/p/RcNjQSg0UvYprTTudZhXUJCTA4DyScCh3oRdpXEEMsHuasT9S9N1ET3wpxnrW5Af/n/natdsecurity/b/misc/o/livelabs-get_started.zip -O livelabs-get_started.zip

if [[ -f livelabs-get_started.zip ]]; then
  unzip -qo livelabs-get_started.zip -d /usr/local/bin/
  chmod +x /usr/local/bin/*.sh
  chmod +x /usr/local/bin/.*.sh
  echo
  echo "Refreshing Remote Desktop Configuration"
  echo
  /usr/local/bin/refresh_desktop.sh
  cd ..
  rm -rf /tmp/ll_refresh
fi
EOF

if [[ ! -f /etc/oci-hostname.conf ]]; then
  cat >/etc/oci-hostname.conf <<EOF
# This configuration file controls the hostname persistence behavior for Oracle Linux
# compute instance on Oracle Cloud Infrastructure (formerly Baremetal Cloud Services)
# Set PRESERVE_HOSTINFO to one of the following values
#   0 -- default behavior to update hostname, /etc/hosts and /etc/resolv.conf to
#        reflect the hostname set during instance creation from the metadata service
#   1 -- preserve user configured hostname across reboots; update /etc/hosts and
#           /etc/resolv.conf from the metadata service
#   2 -- preserve user configured hostname across instance reboots; no custom
#        changes to /etc/hosts and /etc/resolv.conf from the metadata service,
#        but dhclient will still overwrite /etc/resolv.conf
#   3 -- preserve hostname and /etc/hosts entries across instance reboots;
#        update /etc/resolv.conf from instance metadata service
PRESERVE_HOSTINFO=2
EOF
fi

# Create OS user oracle if it doesn't exist
getent passwd oracle >/dev/null
if [[ $? -ne 0 ]]; then
  $pkg_bin -y install oracle-database-preinstall-21c
  getent passwd oracle >/dev/null
  if [[ $? == 0 ]]; then
    su oracle <<'EOB'
id
exit
EOB
  else
    echo
    echo "Creating OS user oracle failed. Please review and address before proceeding, unless having this user is not needed for your workshop"
    echo "Run the following as root: $pkg_bin -y install oracle-database-preinstall-21c"
    echo
  fi
fi

chmod +x /root/bootstrap/firstboot.sh
ln -sf /root/bootstrap/firstboot.sh /var/lib/cloud/scripts/per-instance/firstboot.sh
/var/lib/cloud/scripts/per-instance/firstboot.sh

if [[ $? -ne 0 ]]; then
  echo
  echo "Some error(s) occured. Please review the output, address the issue, and retry accordingly"
  exit 1
else
  clear
  echo
  echo "------------------------------------------------------------------------------------------------------------"
  echo
  echo "Setup Completed successfully for hostname ****$(hostname)**** on: $t_stamp."
  echo
  echo "An entry to ***/etc/hosts** similar to the following will be appended to all future offsprings of the image:"
  echo
  echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
  echo ">>>>"
  echo "$(tail -1 /etc/hosts)"
  echo ">>>>"
  echo "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
  echo
  echo "***INFO****"
  echo
  echo "#1. If you're missing alias(es) or virtualhost name(s) from the output above, please run this script again"
  echo "and provide those as prompted"
  echo
  echo "#2. If you have more host entries you would like added for other servers, e.g. Workshops with multiple images,"
  echo "manually edit ***/root/bootstrap/firstboot.sh**. Refer to the guide for details"
  echo
  echo "------------------------------------------------------------------------------------------------------------"
  echo
  echo "Reconnect as root to continue"
  echo
fi
