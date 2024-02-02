sudo yum install epel-release
sudo yum install snapd
sleep 10s
sudo systemctl enable --now snapd.socket
sleep 10s
sudo ln -s /var/lib/snapd/snap /snap
sudo snap install intellij-idea-community --classic