#!/bin/bash
# install git to allow repository code download
sudo yum install -y git
cd /home/opc/
git clone https://github.com/jasperan/intellij-ocw-london-24
# switch user to root
sudo su - || (sudo sed -i -e 's|root:x:0:0:root:/root:.*$|root:x:0:0:root:/root:/bin/bash|g' /etc/passwd && sudo su -)
cd /tmp
rm -rf ll-setup
mkdir ll-setup
#wget ************************************.ZIP  -O setup-novnc-livelabs.zip
cd /home/opc/intellij-ocw-london-24/automation/

cp /home/opc/intellij-ocw-london-24/automation/* /tmp/ll-setup/.
#unzip -o  setup-novnc-livelabs.zip -d ll-setup
cd /tmp/ll-setup/
chmod +x *.sh .*.sh
./setup-firstboot.sh # && exit
#sudo su - #****** reeconnecting as root here
cd /tmp/ll-setup/
./setup-novnc-livelabs.sh
# after this, install intellij idea community edition with automation/ (this part requires an input key from user)
./install_intellij.sh