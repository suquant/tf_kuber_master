#!/bin/sh
set -e

kubeadm init --config /etc/kubernetes/master-configuration.yml

[ -d $HOME/.kube ] || mkdir -p $HOME/.kube
ln -s /etc/kubernetes/admin.conf $HOME/.kube/config

hostname=$(hostname -s)

until $(kubectl get node $hostname > /dev/null 2>/dev/null); do
  echo "Waiting for api server to respond..."
  sleep 5
done
