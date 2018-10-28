#!/bin/sh
set -e

# Clean etcd
systemctl stop etcd3.service
rm -rf /var/lib/etcd3/member
systemctl start etcd3.service

kubeadm reset --force

iptables -F -t nat

kubeadm init --config /etc/kubernetes/configuration.yml

[ -d $HOME/.kube ] || mkdir -p $HOME/.kube
[ -f $HOME/.kube/config ] || ln -s /etc/kubernetes/admin.conf $HOME/.kube/config

hostname=$(hostname -s)

until $(kubectl get node $hostname > /dev/null 2>/dev/null); do
  echo "Waiting for api server to respond..."
  sleep 5
done

[ -f /etc/kubernetes/weavenet.yml ] && kubectl apply -f /etc/kubernetes/weavenet.yml

#[ -f /etc/kubernetes/kube-router.yml ] && kubectl apply -f /etc/kubernetes/kube-router.yml

# Run kube-router as service proxy
#kubectl -n kube-system delete ds kube-proxy
#docker run --privileged -v /lib/modules:/lib/modules --net=host k8s.gcr.io/kube-proxy-amd64:v1.12.1 kube-proxy --cleanup || true

# Activate IPVS mode
#kubectl -n kube-system get cm kube-proxy -o yaml --export=true > /tmp/kube-proxy-config.yaml
#sed -i 's/mode: ""/mode: "ipvs"/g' /tmp/kube-proxy-config.yaml
#kubectl -n kube-system apply -f /tmp/kube-proxy-config.yaml
#kubectl -n kube-system delete po -l k8s-app=kube-proxy --grace-period=0 --force
# End of activation IPVS mode