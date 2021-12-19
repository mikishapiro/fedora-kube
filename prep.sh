#!/bin/bash -x
ASA=ansible-service-account
FQDN=spica.localdomain
sudo dnf install -y ansible git python-netaddr
cd ~
git clone https://github.com/kubernetes/contrib.git
cd contrib/ansible
cat > inventory/3way.ini << EOF
[masters]
kube-master.example.com

[etcd]
kube-master.example.com

[nodes]
kube-node-01.example.com
kube-node-02.example.com
EOF
cat > inventory/1way.ini << EOF
[masters]
spica.localdomain ansible_connection=local

[nodes]
spica.localdomain ansible_connection=local

[etcd]
spica.localdomain ansible_connection=local
EOF
ln -nfs 1way.ini inventory/inventory
cp -vrfp all.yml inventory/group_vars/all.yml
sudo useradd $ASA
sudo su $ASA -c "ssh-keygen -b 2048 -q -N '' -t rsa -f ~$ASA/.ssh/id_rsa 0>&-"
sudo su $ASA ssh localhost
sudo sed -i 's@127.0.0.1.*@127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4'" $FQDN@" /etc/hosts
sudo su $ASA -c "cat > ~$ASA/.ssh/config << EOF
Host $FQDN
    Hostname 127.0.0.1
    StrictHostKeyChecking no
EOF
"
sudo su $ASA -c "cat ~$ASA/.ssh/id_rsa.pub > ~$ASA/.ssh/authorized_keys; chmod 600 ~$ASA/.ssh/authorized_keys"
sudo usermod -a -G wheel ansible-service-account

# Fixes
# 1. libselinux-python has been named python3-libselinux since Fedora 31
# https://github.com/kubernetes-sigs/kubespray/issues/5622
sed -i 's/    - libselinux-python/    - python3-libselinux\n    - ebtables\n    - device-mapper-libs/'  ./roles/pre-ansible/tasks/fedora-dnf.yml

echo "Now run cd ~/contrib/ansible/scripts ; ./deploy-cluster.sh"
