#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
CP_IP=$(terraform -chdir=terraform/infra output -raw control_plane_public_ip)
ssh root@"$CP_IP" "cat /etc/rancher/k3s/k3s.yaml" \
| sed "s/127.0.0.1/$CP_IP/" > kubeconfig
echo "Hotovo. export KUBECONFIG=\$PWD/kubeconfig && kubectl get nodes"