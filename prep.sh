#!/bin/bash -x
ASA=ansible-service-account
FQDN=spica.localdomain

# pvcreate /dev/mmcblk0p4
# vgextend fedora_fedora /dev/mmcblk0p4
# lvextend -l 100%FREE /dev/fedora_fedora/root 
# xfs_growfs /dev/fedora_fedora/root

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
cp -vrfp ~/fedora-kube/all.yml inventory/group_vars/all.yml
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
sed -i 's/    - libselinux-python/    - python3-libselinux\n    - ebtables\n    - device-mapper-libs\n/'  ./roles/pre-ansible/tasks/fedora-dnf.yml

# 2. etcd
sudo dnf -y install golang-github-cloudflare-cfssl
sed -i 's/^node_ips.*/node_ips=${NODE_IPS[0]}/' ~/contrib/ansible/roles/etcd/files/make-ca-cert.sh
sed -i 's/^curl.*//' ~/contrib/ansible/roles/etcd/files/make-ca-cert.sh
sed -i 's/^chmod.*//' ~/contrib/ansible/roles/etcd/files/make-ca-cert.sh

# 3. docker
sudo mkdir -p /etc/docker
sudo rm -rf /etc/docker/*
sudo dnf -y reinstall moby-engine
sudo systemctl enable docker
sudo systemctl start docker
sudo dnf -y install docker-compose
sed -i 's/| version_compare/is version_compare/' ~/contrib/ansible/roles/docker/tasks/main.yml
# sudo systemctl status docker
# 4. SDN
# openconntrail
# sed -i 's@https://github.com/Juniper/contrail-build@https://github.com/tungstenfabric/tf-build@' ~/contrib/ansible/roles/opencontrail/templates/Dockerfile.redhat.j2

# flannel
#sed -i 's/ set / put /' ~/contrib/ansible/roles/flannel/tasks/config.yml
#sed -i 's/--ca-file=/--cacert=/' ~/contrib/ansible/roles/flannel/tasks/config.yml
#sed -i 's/--cert-file=/--cert=/' ~/contrib/ansible/roles/flannel/tasks/config.yml
#sed -i 's/--key-file=/--key=/' ~/contrib/ansible/roles/flannel/tasks/config.yml
#sed -i 's/--no-sync / /' ~/contrib/ansible/roles/flannel/tasks/config.yml
#sed -i 's/--peers=/--endpoints=/' ~/contrib/ansible/roles/flannel/tasks/config.yml

# 5. master
# this: KUBE_API_ARGS="{{ kube_apiserver_options|join(' ') }} {{ kube_apiserver_additional_options|join(' ') }}" doesn't contain --service-account-signing-key-file= and --service-account-issuer=
sed -i 's@KUBE_API_ARGS=.*@KUBE_API_ARGS="--tls-cert-file=/etc/kubernetes/certs/server.crt --tls-private-key-file=/etc/kubernetes/certs/server.key --client-ca-file=/etc/kubernetes/certs/ca.crt --token-auth-file=/etc/kubernetes/tokens/known_tokens.csv --service-account-key-file=/etc/kubernetes/certs/server.crt --service-account-signing-key-file=/etc/kubernetes/certs/server.key --service-account-issuer=https://kubernetes.default.svc.cluster.local --bind-address=0.0.0.0 --apiserver-count=1"@'  ~/contrib/ansible/roles/master/templates/apiserver.j2 

# 6. pyyaml
sed -i 's/PyYAML/python3-pyyaml/' ~/contrib/ansible/roles/kubernetes-addons/tasks/generic-install.yml
echo "Now run cd ~/contrib/ansible/scripts ; ./deploy-cluster.sh"
