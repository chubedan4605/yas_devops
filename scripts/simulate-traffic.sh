#!/bin/bash

DURATION_SECONDS=${1:-120}
NAMESPACE=${2:-"dev"}

echo ">>> Starting traffic simulation for ${DURATION_SECONDS} seconds in namespace '${NAMESPACE}'..."

exec_wget() {
    local source_app=$1
    local dest_url=$2

    # Find pod name
    local pod=$(kubectl get pod -l "app.kubernetes.io/name=${source_app}" -n "${NAMESPACE}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -z "$pod" ]; then
        pod=$(kubectl get pod -l "app=${source_app}" -n "${NAMESPACE}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    fi

    if [ -n "$pod" ]; then
        local container_name=$source_app
        if [ "$source_app" = "dev-swagger-ui" ]; then
            container_name="swagger-ui"
        fi
        echo "[$(date +%H:%M:%S)] Sending: ${source_app} -> ${dest_url}"
        # Execute in background (fire and forget)
        kubectl exec "${pod}" -n "${NAMESPACE}" -c "${container_name}" -- wget -qO- --timeout=2 "${dest_url}" >/dev/null 2>&1 &
    else
        echo "Warning: Pod for service '${source_app}' not found! Skipping request to ${dest_url}"
    fi
}

start_time=$(date +%s)
end_time=$((start_time + DURATION_SECONDS))

while [ $(date +%s) -lt $end_time ]; do
    echo "[$(date +%H:%M:%S)] --- Starting new traffic batch request ---"
    # 1. UIs calling BFFs/Services
    exec_wget "storefront-ui" "http://storefront-bff/"
    exec_wget "backoffice-ui" "http://backoffice-bff/"
    exec_wget "dev-swagger-ui" "http://product/product/storefront/brands"
    exec_wget "dev-swagger-ui" "http://order/order/actuator/health"

    # 2. BFFs calling Backend Services
    exec_wget "storefront-bff" "http://customer/customer/actuator/health"
    exec_wget "storefront-bff" "http://cart/cart/actuator/health"
    exec_wget "storefront-bff" "http://order/order/actuator/health"
    exec_wget "storefront-bff" "http://product/product/storefront/brands"
    
    exec_wget "backoffice-bff" "http://product/product/storefront/brands"
    exec_wget "backoffice-bff" "http://inventory/inventory/actuator/health"
    exec_wget "backoffice-bff" "http://tax/tax/actuator/health"
    exec_wget "backoffice-bff" "http://media/media/actuator/health"

    # 3. Inter-service backend calls
    exec_wget "order" "http://product/product/storefront/brands"
    exec_wget "order" "http://cart/cart/actuator/health"
    exec_wget "order" "http://customer/customer/actuator/health"
    exec_wget "order" "http://tax/tax/actuator/health"
    exec_wget "order" "http://inventory/inventory/actuator/health"

    exec_wget "cart" "http://product/product/storefront/brands"
    exec_wget "cart" "http://media/media/actuator/health"

    exec_wget "inventory" "http://product/product/storefront/brands"

    exec_wget "search" "http://product/product/storefront/brands"

    exec_wget "customer" "http://product/product/storefront/brands"
    
    exec_wget "tax" "http://product/product/storefront/brands"

    exec_wget "media" "http://product/product/storefront/brands"

    # 4. Sampledata calling product to seed data
    exec_wget "sampledata" "http://product/product/storefront/brands"
    exec_wget "sampledata" "http://media/media/actuator/health"

    sleep 2
done

echo ">>> Traffic simulation complete!"
