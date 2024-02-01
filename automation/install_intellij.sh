sudo yum install epel-release
sudo yum install snapd
sleep 5s
sudo systemctl enable --now snapd.socket
sudo ln -s /var/lib/snapd/snap /snap
sudo snap install intellij-idea-community --classic