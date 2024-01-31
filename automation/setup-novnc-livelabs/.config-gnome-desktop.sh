#!/bin/bash
# Copyright (c) 2021 Oracle and/or its affiliates. All rights reserved.

################################################################################
#
# Name: config-gnome-desktop.sh
#
# Description: Script to optimize desktop
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
#  Rene Fontcha    11/12/2021           Initial Creation
#  Rene Fontcha    11/23/2021           Added routine to trust desktop apps
#  Rene Fontcha    03/23/2022           Added support for Enterprise Linux 8
#  Rene Fontcha    05/19/2022           Replaced Public IP lookup routine
#
################################################################################
el_version=$(uname -r | grep -o -P 'el.{0,1}')

if [[ "${el_version}" == "el8" ]]; then
  gsettings set org.gnome.shell favorite-apps "['livelabs-get_started.desktop', 'google-chrome.desktop', 'org.gnome.Terminal.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.gedit.desktop']"
  sudo dnf remove -y --oldinstallonly --setopt installonly_limit=2 kernel
fi

cd $HOME
cp /usr/local/bin/.set-env*.sh .

v_updated=$(grep ".set-env.sh" $HOME/.bash_profile || grep ".occ_oms.sh" $HOME/.bash_profile)

if [[ $? -ne 0 ]]; then
  echo ". ~/.set-env.sh" >>$HOME/.bash_profile
fi

for v_env in $(ls -a $HOME/.*.sh); do
  sed -i "s|ident.me|ifconfig.me|g" $v_env
done

if [[ -f $HOME/.livelabs/.desktop_configured ]]; then
  echo "No configuration needed"
  exit 1
fi

xrandr --output VNC-0 --mode 1920x1080
sleep 5

if [[ "${el_version}" == "el7" ]]; then
  cd $HOME/Desktop
  cp /usr/share/applications/livelabs-get_started.desktop .
  cp /usr/share/applications/google-chrome.desktop .
  cp /usr/share/applications/org.gnome.Terminal.desktop .
  chmod +x *.desktop
  sed -i "s|^Exec=gnome-terminal.*$|Exec=gnome-terminal --geometry=95x49+1020+45|g" $HOME/Desktop/org.gnome.Terminal.desktop
  sed -i "s|^Exec=/usr/bin/google-chrome.*$|Exec=/usr/bin/google-chrome --disable-gpu --password-store=basic --window-position=1010,30 --window-size=900,990 --disable-session-crashed-bubble|g" ${HOME}/Desktop/google-chrome.desktop
  for i in $(ls $HOME/Desktop); do
    gio set $i "metadata::trusted" yes
  done
fi

killall nautilus >/dev/null 2>&1 && nautilus-desktop >/dev/null 2>&1 &

gprofile_id=$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'")

if [ -z $gprofile_id ]; then
  clear
  echo "================================================================================"
  echo "================================================================================"
  echo "                    GNOME Terminal Profile not found!                           "
  echo "--------------------------------------------------------------------------------"
  echo "                     Do the following to initialize                             "
  echo "                                                                                "
  echo "  1. Right-click on the desktop and select Open Terminal                        "
  echo "  2. Click on Edit > Preferences                                                "
  echo "  3. Under Profiles, click on the arrow next to Unammed, select rename,         "
  echo "     update it to Livelabs and click Close                                      "
  echo "  4. Run this script again. /tmp/ll-setup/.config-gnome-desktop.sh               "
  echo "                                                                                "
  echo "--------------------------------------------------------------------------------"
  echo "================================================================================"
  exit 10
else
  dconf write /org/gnome/terminal/legacy/profiles:/:${gprofile_id}/foreground-color "'rgb(255,255,255)'"
  dconf write /org/gnome/terminal/legacy/profiles:/:${gprofile_id}/background-color "'rgb(0,0,0)'"
  dconf write /org/gnome/terminal/legacy/profiles:/:${gprofile_id}/login-shell "true"
  dconf write /org/gnome/terminal/legacy/profiles:/:${gprofile_id}/use-theme-colors "false"
  dconf write /org/gnome/desktop/screensaver/lock-enabled "false"
  dconf write /org/gnome/nautilus/icon-view/default-zoom-level "'small'"
  dconf write /org/gnome/desktop/notifications/application/org-gnome-packages/enable "false"
  dconf write /org/gnome/desktop/notifications/application/org-gnome-packageupdater/enable "false"
  dconf write /org/gnome/desktop/notifications/application/abrt-applet/enable "false"
  dconf write /org/gnome/desktop/privacy/report-technical-problems "false"
  gsettings set org.gnome.desktop.session idle-delay 'uint32 0'
  gsettings set org.gnome.desktop.notifications show-in-lock-screen "false"
  gsettings set org.gnome.desktop.notifications show-banners "false"
fi

ll_windows_opened=$(ps aux | grep 'disable-session-crashed-bubble' | grep -v grep | awk '{print $2}' | wc -l)
if [[ "${ll_windows_opened}" -gt 0 ]]; then
  kill -2 $(ps aux | grep 'disable-session-crashed-bubble' | grep -v grep | awk '{print $2}')
fi

touch $HOME/.livelabs/.desktop_configured

clear
echo "================================================================================"
echo "================================================================================"
echo "                  Desktop Successfully Optimized for LiveLabs!                  "
echo "--------------------------------------------------------------------------------"
echo "                      Refreshing Desktop session shortly                        "
echo "              Please reconnect accordingly if autoconnect times out             "
echo "                                                                                "
echo "--------------------------------------------------------------------------------"
echo "================================================================================"
sleep 10
sudo systemctl restart vncserver_$(whoami)@\:1.service
