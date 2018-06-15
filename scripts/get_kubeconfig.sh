#!/bin/sh
set -e

eval "$(jq -r '@sh "host=\(.host)"')"

content=$(ssh -o StrictHostKeyChecking=no root@$host "cat /etc/kubernetes/admin.conf | sed 's#server:.*#server: https://$host:6443#g' | base64")

exec jq -n --arg content "$content" '{"content": $content}'