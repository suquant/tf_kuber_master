#!/bin/sh
set -e

tmp_dir=".tf_kuber_master/pki"

mkdir -p $tmp_dir
rsync -apgo -e "ssh -o StrictHostKeyChecking=no" --include "ca.*" --include "sa.*" --exclude "*" root@${src_host}:/etc/kubernetes/pki/ $tmp_dir
ssh -o StrictHostKeyChecking=no root@${dst_host} "mkdir -p /etc/kubernetes/pki"
rsync -apgo -e "ssh -o StrictHostKeyChecking=no" --include "ca.*" --include "sa.*" --exclude "*" $tmp_dir/ root@${dst_host}:/etc/kubernetes/pki/
ssh -o StrictHostKeyChecking=no root@${dst_host} "chown -R root:root /etc/kubernetes/pki && chmod 600 /etc/kubernetes/pki/*.key && chmod 644 /etc/kubernetes/pki/*.crt"
rm -rf $tmp_dir