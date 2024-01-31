#!/bin/bash
# Copyright (c) 2021 Oracle and/or its affiliates. All rights reserved.

################################################################################
#
# Name:setup-novnc-livelabs.sh
#
# Description: Script to deploy noVNC remote desktop
#
#
#  Pre-requisite: This should be executed as "root" user. It assumes that port
#                 80 is currently available and not binded to another application
#                 For cases with such config, special handling is required.
#
#  AUTHOR(S)
#  -------
#  Rene Fontcha, Oracle LiveLabs Platform Lead
#
#  MODIFIED        Date                 Comments
#  --------        ----------           ------------------------------------
#  Rene Fontcha    08/12/2021           Initial Creation
#  Rene Fontcha    09/08/2021           Removed option to custom startup delays
#  Rene Fontcha    10/27/2021           Added NGINX reverse proxy (port 80)
#  Rene Fontcha    03/21/2022           Added support for Enterprise Linux 8
#  Rene Fontcha    04/26/2023           Switched novnc for EL8 to EPEL Repo
#
###############################################################################
shopt -s extglob

if [[ $EUID -ne 0 ]]; then
  echo "Cannot proceed! This script must be run as root"
  exit 1
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

export public_ip=$(curl -s ifconfig.me)
export delay_min=1
echo ${delay_min} >/tmp/ll-setup/.delay_min
echo "NoVNC Startup Delay set to minimum $delay_min min"

while true; do
  echo "*************"
  echo ""
  #read -p 'Please type in the valid OS user to configure for remote desktop access.This is the OS user that owns most of the user processes for the workshop. e.g. *oracle*: ' appuser

  appuser="oracle"
  getent passwd $appuser >/dev/null

  case $? in
  0)
    case "${appuser}" in
    root)
      echo ""
      echo "***ERROR****"
      echo "-- Not allowed for root. -- VNC must be on a non-root account. e.g oracle. Please enter a valid non-root OS user"
      echo ""
      ;;
    *)
      export appuser
      export appuser_home=$(eval echo ~${appuser})
      echo "$appuser" >/tmp/ll-setup/.appuser
      mkdir -p ${appuser_home}/.livelabs
      break
      ;;
    esac
    ;;
  *)
    echo ""
    echo "***ERROR****"
    echo "-- Invalid OS user. -- Please enter a valid non-root OS user"
    echo ""
    ;;
  esac
done

echo "OS User to be configure for remote desktop access is: $appuser"

cat >/tmp/ll-setup/novnc-1.sh <<EOF
#!/bin/bash

echo ""
echo "*************"
echo "Proceeding with remote desktop configuration for OS user \$appuser"

appuser=${appuser}
appuser_home=${appuser_home}
ll_config_base=\${appuser_home}/.livelabs

if [[ "\$el_version" == "el7" ]]; then
  epel_cfg=/etc/yum.repos.d/oracle-epel-ol7.repo
elif [[ "\$el_version" = "el8" ]]; then
  epel_cfg=/etc/yum.repos.d/oracle-epel-ol8.repo
  echo
  echo "Removing older kernel to free up /boot"
  echo
  dnf remove -y --oldinstallonly --setopt installonly_limit=2 kernel
fi

mkdir -p "\${ll_config_base}"
wget https://objectstorage.us-ashburn-1.oraclecloud.com/p/2Pvux7VWE_Cx0v66TohxVWL7KXv2uFNEzw0JYtfMGCcFWDxrY7pHkS6L7-Bcn5on/n/natdsecurity/b/misc/o/livelabs.ico -O "\${ll_config_base}"/livelabs.ico
chown -R \${appuser} "\${ll_config_base}"

if [[ -f "\${epel_cfg}" ]]; then
  sed -i -e 's|enabled=.*\$|enabled=1|g' "\${epel_cfg}"
else
  if [[ "\$el_version" == "el7" ]]; then
    cat > "\${epel_cfg}" <<EPEL
[ol7_developer_EPEL]
name=Oracle Linux \$releasever EPEL Packages for Development (\$basearch)
baseurl=https://yum\$ociregion.\$ocidomain/repo/OracleLinux/OL7/developer_EPEL/\$basearch/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-oracle
gpgcheck=1
enabled=1
EPEL
elif [[ "\$el_version" == "el8" ]]; then
    cat > "\${epel_cfg}" <<EPEL
[ol8_developer_EPEL]
name=Oracle Linux \$releasever EPEL Packages for Development (\$basearch)
baseurl=https://yum\$ociregion.\$ocidomain/repo/OracleLinux/OL8/developer_EPEL/\$basearch/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-oracle
gpgcheck=1
enabled=1
EPEL
  fi
fi

if [[ "\$el_version" == "el7" ]]; then
  $pkg_bin -y erase novnc
fi

echo "Updating packages ..."
  $pkg_bin -y update --skip-broken

echo "Installing X-Server required packages ..."
$pkg_bin -y groupinstall "Server with GUI"
$pkg_bin -y install \
tigervnc-server \
nginx \
figlet

if [[ "\$el_version" == "el7" ]]; then
  echo "Installing other required packages ..."
  $pkg_bin -y install \
  numpy \
  mailcap

  $pkg_bin -y localinstall \
  http://mirror.dfw.rax.opendev.org:8080/rdo/centos7-master/deps/latest/noarch/novnc-1.1.0-6.el7.noarch.rpm \
  http://mirror.dfw.rax.opendev.org:8080/rdo/centos7-master/deps/latest/noarch/python2-websockify-0.8.0-13.el7.noarch.rpm
elif [[ "\$el_version" == "el8" ]]; then
  systemctl set-default graphical
  #setenforce 0
  #sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
  echo "Installing other required packages ..."

  $pkg_bin -y install \
  tigervnc-server-module \
  novnc \
  python3-websockify

  if [[ -f /etc/nginx/nginx.conf ]]; then
     sed -i "s|default_server;|;|g" /etc/nginx/nginx.conf
  fi
fi

$pkg_bin install -y  https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm >/dev/null 2>&1
v_return=\$?

if [[ "\$v_return" -ne 0 ]]; then
  if [[  "\$v_return"  -eq 1 ]]; then
    echo "Google Chrome is current"
    echo ""
  else
    echo "Installing the current version of Google Chrome failed. Attempting to install a lower livelabs certified version"
    echo ""
    $pkg_bin install -y https://dl.google.com/linux/chrome/rpm/stable/x86_64/google-chrome-stable-94.0.4606.61-1.x86_64.rpm
  fi
fi

if [[ -f /etc/systemd/system/vncserver_\${appuser}@:1.service ]]; then
  v_updated=\$(grep -w "resetvncpwd" /etc/systemd/system/vncserver_\${appuser}@:1.service | wc -l)
  if [[ \$v_updated == 1 ]]; then
    echo "VNC Service already configured. Skipping"
  else
    echo "Updating VNC Service ..."
    cp /lib/systemd/system/vncserver@.service /etc/systemd/system/vncserver_\${appuser}@:1.service
    sed -i "s/After=syslog.target network.target/After=syslog.target network.target resetvncpwd.service cloud-final.service/g" /etc/systemd/system/vncserver_\${appuser}@:1.service

    if [[ "\$el_version" == "el7" ]]; then
      sed -i "s/<USER>/\${appuser}/g" /etc/systemd/system/vncserver_\${appuser}@:1.service
    elif [[ "\$el_version" == "el8" ]]; then
      v_updated=\$(grep -w ":1=${appuser}" /etc/tigervnc/vncserver.users | wc -l)

      if [ "\${v_updated}" == 0 ]; then
        echo ":1=${appuser}" >>/etc/tigervnc/vncserver.users
      fi
    fi
  fi
else
  echo "Updating VNC Service ..."
  cp /lib/systemd/system/vncserver@.service /etc/systemd/system/vncserver_\${appuser}@:1.service
  sed -i "s/After=syslog.target network.target/After=syslog.target network.target resetvncpwd.service cloud-final.service/g" /etc/systemd/system/vncserver_\${appuser}@:1.service

  if [[ "\$el_version" == "el7" ]]; then
    sed -i "s/<USER>/\${appuser}/g" /etc/systemd/system/vncserver_\${appuser}@:1.service
  elif [[ "\$el_version" == "el8" ]]; then
    systemctl stop vncserver@\:1.service
    systemctl disable vncserver@\:1.service
    v_updated=\$(grep -w ":1=${appuser}" /etc/tigervnc/vncserver.users | wc -l)
    if [ "\${v_updated}" == 0 ]; then
      echo ":1=${appuser}" >>/etc/tigervnc/vncserver.users
    fi
  fi
fi

firewall-cmd --zone=public --permanent --add-service=vnc-server
firewall-cmd --zone=public --permanent --add-port=5901/tcp
firewall-cmd --permanent --add-port=6080/tcp
firewall-cmd --permanent --add-port=80/tcp
setsebool -P httpd_can_network_connect 1

firewall-cmd  --reload
systemctl daemon-reload

su \${appuser} <<'EOB3'
mypasswd="LiveLabs.Rocks_99"
rm -rf \$HOME/.vnc
mkdir \$HOME/.vnc
echo \$mypasswd | vncpasswd -f >\$HOME/.vnc/passwd
chmod 600 \$HOME/.vnc/passwd
vncserver
sleep 5

#Drop any running google-chrome session
ll_windows_opened=\$(ps aux | grep 'disable-session-crashed-bubble' | grep -v grep | awk '{print \$2}' | wc -l)
if [[ "\${ll_windows_opened}" -gt 0 ]]; then
  kill -2 \$(ps aux | grep 'disable-session-crashed-bubble' | grep -v grep | awk '{print \$2}')
  echo
  echo "---- \${ll_windows_opened} browser session(s) terminated ----"
  echo
fi
vncserver -kill :1
exit
EOB3

if [[ \$? -eq 0 ]]; then
  echo ""
  echo "***********************"
  echo "Successfully executed!"
  echo "***********************"
  echo ""
else
  echo ""
  echo "***********************"
  echo "Some failure occured. Please review before proceeding"
  echo "***********************"
  echo ""
fi

# # Update "livelabs-get_started.sh"
# cd /tmp/ll-setup
# wget -q https://objectstorage.us-ashburn-1.oraclecloud.com/p/RcNjQSg0UvYprTTudZhXUJCTA4DyScCh3oRdpXEEMsHuasT9S9N1ET3wpxnrW5Af/n/natdsecurity/b/misc/o/livelabs-get_started.zip -O livelabs-get_started.zip
#
# if [[ -f livelabs-get_started.zip ]]; then
#   unzip -qo livelabs-get_started.zip -d /usr/local/bin/
#   chmod +x /usr/local/bin/*.sh
#   chmod +x /usr/local/bin/.*.sh
#   rm -f livelabs-get_started.zip
# fi

if [ ! -d "\${appuser_home}/.config/autostart" ]; then
  mkdir \${appuser_home}/.config/autostart
fi
cat >\${appuser_home}/.config/autostart/livelabs-get_started.sh.desktop <<EOB1
[Desktop Entry]
Type=Application
Exec=/usr/local/bin/livelabs-get_started.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name[en_US]=Get Started with your Workshop
Name=Get Started with your Workshop
Comment[en_US]=Launch Workshop Guide and WebApps
Comment=Launch Workshop Guide and WebApps
EOB1

cat >\${appuser_home}/.config/autostart/optimized-gnome.sh.desktop <<EOB2
[Desktop Entry]
Type=Application
Exec=/usr/local/bin/.config-gnome-desktop.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name[en_US]=Optimze Gnome Desktop for Livelabs
Name=Optimze Gnome Desktop for Livelabs
Comment[en_US]=Launch Optimze Gnome Desktop for Livelabs
Comment=Launch Optimze Gnome Desktop for Livelabs
EOB2

chmod +x \${appuser_home}/.config/autostart/*.desktop

if [ -f "\${appuser_home}/.config/monitors.xml" ]; then
  sed -i "s|<width.*\$|<width>1920</width>|g" \${appuser_home}/.config/monitors.xml
  sed -i "s|<height.*\$|<height>1080</height>|g" \${appuser_home}/.config/monitors.xml
else
  cp /tmp/ll-setup/monitors.xml \${appuser_home}/.config/
fi

# Customize Google Chrome and Terminal applications
sed -i "s|^Exec=gnome-terminal.*\$|Exec=gnome-terminal --geometry=95x49+1020+45|g" /usr/share/applications/org.gnome.Terminal.desktop

if [[ "\$el_version" == "el7" ]]; then
  sed -i "s|^Exec=/usr/bin/google-chrome.*\$|Exec=/usr/bin/google-chrome --disable-gpu --password-store=basic --window-position=1010,30 --window-size=900,990 --disable-session-crashed-bubble|g" /usr/share/applications/google-chrome.desktop
elif [[ "\$el_version" == "el8" ]]; then
  sed -i "s|^Exec=/usr/bin/google-chrome.*\$|Exec=/usr/bin/google-chrome --disable-gpu --password-store=basic --window-position=970,30 --window-size=940,990 --disable-session-crashed-bubble|g" /usr/share/applications/google-chrome.desktop
fi

EOF

cat >/tmp/ll-setup/novnc-2.sh <<EOF
#!/bin/bash

#Enable and Start services

systemctl daemon-reload

for i in delay-vncserver.timer delay-websockify.timer resetvncpwd nginx
  do
    systemctl enable \${i}
    systemctl start \${i}

    if [[ \$? -eq 0 ]]; then
      echo ""
      echo "***********************"
      echo "Successfully enabled and started \${i}!"
      echo "***********************"
      echo ""
    else
      echo ""
      echo "***********************"
      echo "Some failure occured while starting \${i}. Please review and address"
      echo "***********************"
      echo ""
    fi
  done

systemctl list-timers delay*
systemctl disable websockify
systemctl start websockify

vncpwd=\$(curl -s -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/metadata/vncpwd)

if [[ \${#vncpwd} -ne 10  ]]; then
  vncpwd="LiveLabs.Rocks_99"
fi

#clear
echo "================================================================================"
echo "================================================================================"
echo "             noVNC has been successfully deployed on this host!                 "
echo "--------------------------------------------------------------------------------"
echo "         Open the browser and navigate to the URL below to validate             "
echo "                                                                                "
echo "http://${public_ip}/livelabs/vnc.html?password=\${vncpwd}&resize=scale&quality=9&autoconnect=true&reconnect=true"
echo "                                                                                "
echo "  **Notes:** If the URL above fails to load, verify that:                       "
echo "   (1) Your VCN contains an *ingress* rule for ports *80*                       "
echo "   (2) NGINX service is up and healthy (systemct status nginx)                  "
echo "   (3) If above 2 are OK, try the URL below as well                             "
echo "                                                                                "
echo "--------------------------------------------------------------------------------"
echo "                                                                                "
echo "http://${public_ip}:6080/vnc.html?password=\${vncpwd}&resize=scale&quality=9&autoconnect=true&reconnect=true"
echo "                                                                                "
echo "                                                                                "
echo "  **Notes:** If the URL above fails to load, verify that:                       "
echo "   (1) Your VCN contains an *ingress* rule for ports *6080*                     "
echo "--------------------------------------------------------------------------------"
echo "================================================================================"
echo "                                                                                "
echo "                                                                                "
EOF

cat >/etc/systemd/system/delay-vncserver.timer <<EOF
[Unit]
Description=Delay vncserver startup until ${delay_min} min after boot

[Timer]
OnBootSec=${delay_min}min
Unit=vncserver_${appuser}@:1.service

[Install]
WantedBy=timers.target
EOF

cat >/etc/systemd/system/delay-websockify.timer <<EOF
[Unit]
Description=Delay websockify startup until ${delay_min} min after boot

[Timer]
OnBootSec=${delay_min}min
Unit=websockify.service

[Install]
WantedBy=timers.target
EOF

cat >/usr/local/bin/resetvncpwd.sh <<EOF
#!/bin/bash
# Reset VNC password for user

mypasswd=\$(curl -s -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance/metadata/vncpwd)

if [[ \${#mypasswd} -ne 10  ]]; then
  echo "Required Random password string is missing from OCI metadata. No VNC password reset for user ${appuser} will be performed"
  exit 30
else
  echo \$mypasswd | vncpasswd -f >${appuser_home}/.vnc/passwd
  chmod 0600 ${appuser_home}/.vnc/passwd
  echo "VNC password for user ${appuser} reset successfully"
fi
EOF

cat >/etc/systemd/system/websockify.service <<EOF
[Unit]
Description=Websockify Service
After=network.target cloud-final.service vncserver_${appuser}@:1.service

[Service]
Type=simple
User=${appuser}
ExecStart=/bin/websockify --web=/usr/share/novnc/ --wrap-mode=respawn 6080 localhost:5901
Restart=on-abort

[Install]
WantedBy=multi-user.target
EOF

cat >/etc/systemd/system/resetvncpwd.service <<EOF
[Unit]
Description=ResetVncPwd Service
After=syslog.target network.target cloud-final.service

[Service]
Type=simple
ExecStart=/usr/local/bin/resetvncpwd.sh ${appuser}
Restart=on-failure
RestartSec=30
StartLimitInterval=600
StartLimitBurst=10

[Install]
WantedBy=multi-user.target
EOF

v_updated=$(grep -w "# User rules for ${appuser}" /etc/sudoers.d/90-cloud-init-users | wc -l)

if [ "${v_updated}" == 0 ]; then
  cat >>/etc/sudoers.d/90-cloud-init-users <<EOF

#Livelabs User rules for ${appuser}
${appuser} ALL=(ALL) NOPASSWD:ALL
EOF
fi

cat >/usr/share/applications/livelabs-get_started.desktop <<EOF
[Desktop Entry]
Version=1.0
Encoding=UTF-8
GenericName=Get Started
Name=Get Started with your Workshop
Comment=Launch Apps and Workshop Guide
Exec=/usr/local/bin/livelabs-get_started.sh
StartupNotify=true
Terminal=false
Icon=${appuser_home}/.livelabs/livelabs.ico
Type=Application
Categories=Network;WebBrowser;
MimeType=application/pdf;application/rdf+xml;application/rss+xml;application/xhtml+xml;application/xhtml_xml;application/xml;image/gif;image/jpeg;image/png;image/webp;text/html;text/xml;x-scheme-handler/http;x-scheme-handler/https;
EOF

cat >${appuser_home}/.livelabs/init_ll_windows.sh <<EOF
#!/bin/bash
# Initialize LL Windows

desktop_guide_url="https://oracle.github.io/learning-library/sample-livelabs-templates/sample-workshop/workshops/sandbox"
desktop_app1_url="https://oracle.com"
desktop_app2_url="https://bit.ly/golivelabs"

el_version=\$(uname -r | grep -o -P 'el.{0,1}')
user_data_dir_base="\$HOME/.livelabs"
dir_1=('--user-data-dir=' "\${user_data_dir_base}" '/chrome-window1')
user_data_dir1=\$(printf %s "\${dir_1[@]}" \$'\n')

el7_win_loc1=('--window-position=110,50' '--window-size=895,950')
el7_win_loc2=('--window-position=1010,30' '--window-size=900,990')
el8_win_loc1=('--window-position=30,50' '--window-size=940,950')
el8_win_loc2=('--window-position=970,30' '--window-size=940,990')

if [[ "\${el_version}" == "el7" ]]; then
  win_loc1="\${el7_win_loc1[@]}"
  win_loc2="\${el7_win_loc2[@]}"
  if [[ -d \${user_data_dir_base}/chrome-window2 ]]; then
    dir_2=('--user-data-dir=' "\${user_data_dir_base}" '/chrome-window2')
    user_data_dir2=\$(printf %s "\${dir_2[@]}" \$'\n')
  fi
elif [[ "\${el_version}" == "el8" ]]; then
  win_loc1="\${el8_win_loc1[@]}"
  win_loc2="\${el8_win_loc2[@]}"
fi

#Drop existing sessions
ll_windows_opened=\$(ps aux | grep 'disable-session-crashed-bubble' | grep -v grep | awk '{print \$2}' | wc -l)

if [[ "\${ll_windows_opened}" -gt 0 ]]; then
  kill -2 \$(ps aux | grep 'disable-session-crashed-bubble' | grep -v grep | awk '{print \$2}')
fi

cat >run_cmd.sh<<EOB
#!/bin/bash
# Initialize LiveLabs Desktop for Oracle Enterprise Linux \$el_version"
EOB

#Launching the workshop guide
if [[ "\${desktop_guide_url:0:4}" == 'http' ]]; then
  cmd=("google-chrome --disable-gpu --password-store=basic" "--app=\${desktop_guide_url}" "\${win_loc1}" "\${user_data_dir1}" "--disable-session-crashed-bubble >/dev/null 2>&1 &")
  echo  "\${cmd[@]}" >>run_cmd.sh
fi

#Launching Web App #1 page
if [[ "\${desktop_app1_url:0:4}" == 'http' ]]; then
  if [[ "\${desktop_app1_url:0:5}" == 'https' ]]; then
    cmd=("google-chrome --disable-gpu --password-store=basic" "\${desktop_app1_url}" "\${win_loc2}" "\${user_data_dir2}" "--disable-session-crashed-bubble --ignore-certificate-errors --ignore-urlfetcher-cert-requests >/dev/null 2>&1 &")
    echo  "\${cmd[@]}" >>run_cmd.sh
  else
    cmd=("google-chrome --disable-gpu --password-store=basic" "\${desktop_app1_url}" "\${win_loc2}" "\${user_data_dir2}" "--disable-session-crashed-bubble >/dev/null 2>&1 &")
    echo  "\${cmd[@]}" >>run_cmd.sh
  fi
fi

#Launching Web App #2 page
if [[ "\${desktop_app2_url:0:4}" == 'http' ]]; then
  if [[ "\${desktop_app2_url:0:5}" == 'https' ]]; then
    cmd=("google-chrome --disable-gpu --password-store=basic" "\${desktop_app2_url}" "\${win_loc2}" "\${user_data_dir2}" "--disable-session-crashed-bubble --ignore-certificate-errors --ignore-urlfetcher-cert-requests >/dev/null 2>&1 &")
    echo  "\${cmd[@]}" >>run_cmd.sh
  else
    cmd="google-chrome --disable-gpu --password-store=basic" "\${desktop_app2_url}" "\${win_loc2}" "\${user_data_dir2}" "--disable-session-crashed-bubble >/dev/null 2>&1 &"
    echo  "\${cmd[@]}" >>run_cmd.sh
  fi
fi
chmod +x run_cmd.sh
#cat run_cmd.sh
./run_cmd.sh
EOF

cat >/etc/profile.d/livelabs.sh <<EOF

#Livelabs
PROMPT_COMMAND=__prompt_command
__prompt_command() {
    local EXIT="\$?"
    PS1=""
    local RCol='\[\e[0m\]'
    local Red='\[\e[0;31m\]'
    local Gre='\[\e[0;32m\]'
    local BYel='\[\e[1;33m\]'
    local Cyan='\[\e[0;36m\]'

    if [ \$EXIT != 0 ]; then
      if [ -z "\${ORACLE_SID}" ]; then
        PS1+="[\${Red}\u\${RCol}"
      else
        PS1+="[\${Cyan}\${ORACLE_SID}:\${Red}\u\${RCol}"
      fi
    else
      if [ -z "\${ORACLE_SID}" ]; then
        PS1+="[\${Cyan}\u\${RCol}"
      else
        PS1+="[\${Cyan}\${ORACLE_SID}:\u\${RCol}"
      fi
    fi

    PS1+="\${RCol}@\${Cyan}\h:\${BYel}\w\${RCol}]\${BYel}\$ \${RCol}"
}
EOF

if [[ "$el_version" == "el8" ]]; then
  cat >/etc/polkit-1/localauthority/50-local.d/repos.pkla <<EOF
[Allow Package Management all Users]
Identity=unix-user:*
Action=org.freedesktop.packagekit.system-sources-refresh
ResultAny=yes
ResultInactive=yes
ResultActive=yes
EOF
  systemctl restart polkit
fi

v_updated=$(grep -w "#Livelabs" ${appuser_home}/.bashrc | wc -l)

if [ "${v_updated}" == 0 ]; then
  cat /etc/profile.d/livelabs.sh >>${appuser_home}/.bashrc
fi

#Drop existing google-chrome sessions
ll_windows_opened=$(ps aux | grep 'disable-session-crashed-bubble' | grep -v grep | awk '{print $2}' | wc -l)
if [[ "${ll_windows_opened}" -gt 0 ]]; then
  kill -2 $(ps aux | grep 'disable-session-crashed-bubble' | grep -v grep | awk '{print $2}')
  echo
  echo "---- ${ll_windows_opened} browser session(s) terminated ----"
  echo
fi

chmod +x /usr/local/bin/resetvncpwd.sh
chmod +x ${appuser_home}/.livelabs/init_ll_windows.sh
chmod +x /tmp/ll-setup/novnc-*.sh

if [[ -f /etc/systemd/system/vncserver_${appuser}@:1.service ]]; then
  systemctl disable vncserver_${appuser}@:1.service
  systemctl stop vncserver_${appuser}@:1.service
fi

rm -rf /tmp/.X11-unix/X1
rm -rf /tmp/.X1-lock

./novnc-1.sh

if [ ! -d /etc/nginx/conf.d ]; then
  mkdir -p /etc/nginx/conf.d
fi

cat >/etc/nginx/conf.d/livelabs.conf <<EOF
server {
    listen 80;
    server_name localhost;

    access_log  /var/log/nginx/novnc_access.log;
    error_log  /var/log/nginx/novnc_error.log;

    location /websockify {
          proxy_http_version 1.1;
          proxy_pass http://localhost:6080;
          proxy_set_header Upgrade \$http_upgrade;
          proxy_set_header Connection "upgrade";

          # VNC connection timeout
          proxy_read_timeout 120s;

          # Disable cache
          proxy_buffering off;
    }

    location /livelabs {
            index vnc.html;
            alias /usr/share/novnc/;
            try_files \$uri \$uri/ /vnc.html;
    }
}
EOF

if [[ "$el_version" == "el8" ]]; then
  systemctl stop vncserver@\:1.service
  systemctl disable vncserver@\:1.service
fi

systemctl start vncserver_${appuser}@:1.service
systemctl status vncserver_${appuser}@:1.service

./novnc-2.sh

#Stop resetvncpwd to prevent constinous Restart due to missing required metadata from source system
systemctl stop resetvncpwd
#Retstart key Services
systemctl restart websockify.service vncserver_${appuser}@:1.service nginx.service
