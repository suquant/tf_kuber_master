#!/bin/sh
set -e

echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/ipv4_forward.conf
sysctl -p /etc/sysctl.d/ipv4_forward.conf

curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

add-apt-repository -y ppa:wireguard/wireguard

cat <<EOF > /etc/apt/sources.list.d/kubernetes.list
deb [arch=amd64] https://apt.kubernetes.io/ kubernetes-xenial main
EOF

apt update
DEBIAN_FRONTEND=noninteractive apt install -yq \
    kubelet kubeadm kubectl kubernetes-cni \
    wireguard linux-headers-$(uname -r) linux-headers-virtual