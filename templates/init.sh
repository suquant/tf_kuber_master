#!/bin/sh
set -e

kubeadm reset --force
kubeadm init --config /etc/kubernetes/configuration.yml

[ -d $HOME/.kube ] || mkdir -p $HOME/.kube
[ -f $HOME/.kube/config ] || ln -s /etc/kubernetes/admin.conf $HOME/.kube/config

hostname=$(hostname -s)

until $(kubectl get node $hostname > /dev/null 2>/dev/null); do
  echo "Waiting for api server to respond..."
  sleep 5
done

[ -f /etc/kubernetes/kube-router.yml ] && kubectl apply -f /etc/kubernetes/kube-router.yml
kubectl -n kube-system delete ds kube-proxy