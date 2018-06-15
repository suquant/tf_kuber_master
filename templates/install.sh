#!/bin/sh
set -e

curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

cat <<EOF > /etc/apt/sources.list.d/kubernetes.list
deb [arch=amd64] https://apt.kubernetes.io/ kubernetes-xenial main
EOF

apt update
DEBIAN_FRONTEND=noninteractive apt install -yq \
    kubelet kubeadm kubectl kubernetes-cni \
    wireguard linux-headers-$(uname -r) linux-headers-virtual