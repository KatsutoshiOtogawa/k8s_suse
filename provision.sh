#! /bin/bash

zypper up -y

zypper in -y neovim
zypper in -y nmap
zypper in -y mlocate

# kubernetes is neeed to swap off
# disable swap
swapoff -a
# swapdisk時代をコメントアウトしておくと、使われなくなる。
# [](https://docs.oracle.com/cd/F33069_01/start/swap.html)

cat << END >> /etc/systemd/system/swapoff.service
[Unit]
Description=swapoff for k8s running.
After=network-online.target

[Service]
User=root
ExecStart=/usr/sbin/swapoff

[Install]
WantedBy=multi-user.target
END

systemctl enable swapoff.service

# install dependency on crio
zypper in -y \
    zstd \
    curl \
    gnupg

zypper in -y cri-o cri-tools

cat > /etc/modules-load.d/crio.conf <<EOF
# module load for crio
overlay
br_netfilter
EOF

# ここの後の処処のため、即即実行
modprobe br_netfilter

# persistent parameter.
cat > /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl --system

systemctl daemon-reload
systemctl enable crio
systemctl start crio

# install k8s dependency
zypper in -y \
    ebtables \
    ethtool

zypper in -y \
    'kubernetes1.20-kubelet=1.20.13-lp154.1.7' \
    'kubernetes1.20-kubeadm=1.20.13-lp154.1.7' \
    'kubernetes1.20-client=1.20.13-lp154.1.7' 

systemctl enable kubelet
systemctl start kubelet


# suseはデフォルのimage repositoryが registry.opensuse.orgにななっていため指指すす。
# suseのrepositoryはtumbleweed用。

# localhostをadmin, master, workerとして実行
# /etc/kubernetes/admin.confなどを作作すす。
kubeadm init --image-repository k8s.gcr.io --kubernetes-version=v1.20.13

# defaultはvagrant
user=$(cat /etc/passwd | awk -F: '{if($3==1000){print $1}}')

mkdir /home/${user}/.kube
cp /etc/kubernetes/admin.conf /home/${user}/.kube/config
chown ${user}:${user} /home/${user}/.kube/config

# 設設用のimageをダウンロード
kubeadm config images pull --image-repository k8s.gcr.io

zypper in -y podman

updatedb
