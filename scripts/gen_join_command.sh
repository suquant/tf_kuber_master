#!/bin/sh
set -e

eval "$(jq -r '@sh "host=\(.host)"')"

command=$(ssh -o StrictHostKeyChecking=no root@$host "kubeadm token create --print-join-command || echo 'true'")

exec jq -n --arg command "$command" '{"command": $command}'