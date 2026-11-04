#!/bin/bash
services=("product" "tax" "cart" "customer" "inventory" "media" "order" "search" "sampledata" "storefront-bff" "backoffice-bff")

for svc in "${services[@]}"; do
  echo "Patching deployment: $svc..."
  kubectl patch deployment "$svc" -n staging --patch '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-java":"true","instrumentation.opentelemetry.io/container-names":"'"$svc"'"}}}}}'
done
