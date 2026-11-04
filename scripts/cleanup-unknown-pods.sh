#!/bin/bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=== Force deleting Unknown/Error pods ==="
for ns in argocd dev staging elasticsearch keycloak observability kafka; do
    PODS=$(kubectl get pods -n $ns --no-headers 2>/dev/null | awk '{if ($4=="Unknown" || $4=="Error") print $1}')
    if [ -n "$PODS" ]; then
        echo "Namespace $ns: deleting $PODS"
        echo "$PODS" | xargs kubectl delete pod -n $ns --force --grace-period=0 2>/dev/null
    fi
done

echo ""
echo "=== Waiting 20s for pods to restart ==="
sleep 20

echo ""
echo "=== Final pod status (non-Running) ==="
kubectl get po -A | grep -v "Running\|Completed\|NAME"
