#!/bin/bash
# List all tables
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl exec -n postgres postgresql-0 -- psql -U yasadminuser -d grafana -c '\dt'
