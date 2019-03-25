#!/bin/bash

echo "Type the IP Address of the machine, followed by [ENTER]: "
read HOSTNAME

# remove swap remove the line for swap on /etc/fstab
swapoff -a  

sudo yum -y install ntp wget


cat << EOF | sudo tee -a /etc/systemd/timesyncd.conf
[Time]
NTP=0.de.pool.ntp.org 1.de.pool.ntp.org
FallbackNTP=0.pool.ntp.org 1.pool.ntp.org 0.fr.pool.ntp.org
EOF

# Set time-zone
timedatectl set-timezone Europe/Berlin
sudo timedatectl set-ntp true 



# Open port 6443 & 10250 for kubernetes cluster 
Sudo firewall-cmd --permanent --zone=public --add-port=6443/tcp
sudo firewall-cmd --permanent --zone=public --add-port=10250/tcp
sudo firewall-cmd --permanent --zone=public --add-port=80/tcp
sudo firewall-cmd --permanent --zone=public --add-port=443/tcp
sudo firewall-cmd --permanent --zone=public --add-port=8443/tcp
sudo firewall-cmd --permanent --zone=public --add-port=22/tcp

##############################################################
# Docker Install and set-up
##############################################################

sudo -- sh -c -e {"yum remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine";
"yum update -y";
"yum upgrade -y";
"yum install -y yum-utils device-mapper-persistent-data lvm2 ";
"yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo";
"yum install -y docker-ce-18.06.3.ce-3.el7 docker-ce-cli-18.06.3.ce-3.el7 containerd.io"}

sudo -- sh -c -e "yum remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine";
sudo -- sh -c -e "yum update -y";
sudo -- sh -c -e "yum upgrade -y";
sudo -- sh -c -e "yum install -y yum-utils device-mapper-persistent-data lvm2 ";
sudo -- sh -c -e "yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo";
sudo -- sh -c -e "yum install -y docker-ce-18.06.3.ce-3.el7 docker-ce-cli-18.06.3.ce-3.el7 containerd.io";



yum install https://download.docker.com/linux/centos/7/x86_64/stable/Packages/docker-ce-18.06.3.ce-3.el7.x86_64.rpm



yum install https://download.docker.com/linux/centos/7/x86_64/stable/Packages/docker-ce-cli-18.09.3-3.el7.x86_64.rpm

yum install https://download.docker.com/linux/centos/7/x86_64/stable/Packages/docker-ce-selinux-17.03.3.ce-1.el7.noarch.rpm



# Allow communication with an insecure registry on address 172.30.0.0/16  /etc/docker/daemon.json
 #####  Copy file
cat << EOF | sudo tee -a /etc/docker/daemon.json
{
"insecure-registries": ["172.30.0.0/16"],
"selinux-enabled": true
}
EOF

# Assign the group to your user
sudo usermod -a -G docker kanchen

sudo -- sh -c -e "systemctl start docker";
sudo -- sh -c -e "systemctl enable docker";

# write in /etc/hosts
sudo rm -Rf /etc/hosts
cat << EOF | sudo tee -a /etc/hosts
127.0.0.1   ${HOSTNAME} localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
EOF

##############################################################
# Firewall set-up for OKD
##############################################################

# Add a new firewall zone for OKD
sudo firewall-cmd --permanent --new-zone okdlocal

# Include the Docker bridge network subnet into the new Firewall Zone
sudo firewall-cmd --permanent --zone okdlocal --add-source 172.17.0.0/16

# Firewall rules for the OKD zone
sudo firewall-cmd --permanent --zone okdlocal --add-port 8443/tcp
sudo firewall-cmd --permanent --zone okdlocal --add-port 53/udp
sudo firewall-cmd --permanent --zone okdlocal --add-port 8053/udp

# reload the firewall to perform changes
sudo firewall-cmd --reload

# To ensure the new zone is in place
sudo firewall-cmd --zone okdlocal --list-sources

# To ensure the rules are in places for the OKD zone
sudo firewall-cmd --zone okdlocal --list-ports

##############################################################
# OKD client tools
##############################################################

#move to tmp directory
cd /tmp
wget https://github.com/openshift/origin/releases/download/v3.11.0/openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit.tar.gz
tar -xzvf openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit.tar.gz
sudo cp openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit/oc /usr/bin/
sudo rm -Rf openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit*
cd

sudo touch /usr/local/bin/start_openshift.sh

cat << EOF | sudo tee -a /usr/local/bin/start_openshift.sh
#!/bin/bash
# File /usr/local/bin/start_openshift.sh
sudo cd /opt/openshift/
/usr/bin/oc cluster up --public-hostname=${HOSTNAME}
EOF

cat << EOF | sudo tee -a /etc/systemd/system/openshift.service
# File : /etc/systemd/system/openshift.service
[Unit]
Description=OpenShift Origin Server
[Service]
Type=simple
ExecStart=/usr/local/bin/start_openshift.sh
EOF

# In order to make our service work
# Create a startup script for openshift : /usr/local/bin/start_openshift.sh
sudo chmod u+x /usr/local/bin/start_openshift.sh
sudo mkdir /opt/openshift/

sudo systemctl daemon-reload
sudo systemctl start openshift

cat << EOF | sudo tee -a /root/.bashrc
export KUBECONFIG=/openshift.local.clusterup/kube-apiserver/admin.kubeconfig
export CURL_CA_BUNDLE=/openshift.local.clusterup/kube-apiserver/ca.crt
EOF
