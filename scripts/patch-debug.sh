#!/bin/bash
kubectl patch deployment product -n staging --patch '{"spec":{"template":{"spec":{"containers":[{"name":"product","env":[{"name":"OTEL_JAVAAGENT_DEBUG","value":"true"},{"name":"OTEL_INSTRUMENTATION_LOGBACK_MDC_ENABLED","value":"true"}]}]}}}}'
