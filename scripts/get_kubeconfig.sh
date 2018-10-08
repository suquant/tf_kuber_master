#!/bin/sh
set -e

eval "$(jq -r '@sh "host=\(.host)"')"

content=$(ssh -o StrictHostKeyChecking=no root@$host "cat /etc/kubernetes/admin.conf | base64")

exec jq -n --arg content "$content" '{"content": $content}'