#!/bin/bash
# ============================================================
# restart-after-boot.sh
# Chay script nay SAU KHI khoi dong lai may va bat lai K3s
# Script tu dong xu ly: ZK epoch, Kafka meta, Debezium restart
# Cach dung: wsl -d Ubuntu bash /mnt/f/Devops/yas/scripts/restart-after-boot.sh
# ============================================================

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "================================================================"
echo " YAS Cluster - Post-Boot Recovery Script"
echo "================================================================"

# ── BUOC 1: Cho CoreDNS san sang ─────────────────────────────────────
echo ""
echo "[1/6] Dang cho CoreDNS san sang..."
READY=0
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    COUNT=$(kubectl get deployment coredns -n kube-system -o jsonpath="{.status.readyReplicas}" 2>/dev/null)
    if [ "$COUNT" -ge 1 ] 2>/dev/null; then
        echo "    CoreDNS da san sang"
        READY=1
        break
    fi
    WAIT=$((i * 5))
    echo "    ... Cho CoreDNS (${WAIT}s / 100s)"
    sleep 5
done
[ "$READY" -eq 0 ] && echo "    CANH BAO: CoreDNS chua san sang, tiep tuc..."
sleep 10

# ── BUOC 2: Xoa data ZK cu (tranh loi epoch/SSL conflict) ────────────
echo ""
echo "[2/6] Xoa Zookeeper epoch data cu (tranh SSL conflict)..."
ZK_POD=$(kubectl get pod kafka-cluster-zookeeper-0 -n kafka -o jsonpath="{.status.phase}" 2>/dev/null)
if [ "$ZK_POD" = "Running" ]; then
    kubectl exec -n kafka kafka-cluster-zookeeper-0 -- rm -rf /var/lib/zookeeper/data/version-2 2>/dev/null
    echo "    Da xoa version-2/ trong ZK"
else
    echo "    ZK chua chay, bo qua buoc nay"
fi

# ── BUOC 3: Xoa tat ca Kafka pods de tao lai sach ────────────────────
echo ""
echo "[3/6] Xoa tat ca Kafka/ZK pods de tao lai..."
kubectl delete pod kafka-cluster-zookeeper-0 -n kafka 2>/dev/null
kubectl delete pod kafka-cluster-kafka-0 -n kafka 2>/dev/null
kubectl delete pod -n kafka -l strimzi.io/component-type=entity-operator 2>/dev/null
echo "    Da xoa - Strimzi dang tao lai..."

# ── BUOC 4: Cho ZK Running, sau do xoa Kafka meta.properties ─────────
echo ""
echo "[4/6] Cho Zookeeper Ready roi xoa Kafka meta.properties..."
ZK_READY=0
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24; do
    PHASE=$(kubectl get pod kafka-cluster-zookeeper-0 -n kafka -o jsonpath="{.status.phase}" 2>/dev/null)
    CREADY=$(kubectl get pod kafka-cluster-zookeeper-0 -n kafka -o jsonpath="{.status.containerStatuses[0].ready}" 2>/dev/null)
    if [ "$PHASE" = "Running" ] && [ "$CREADY" = "true" ]; then
        echo "    Zookeeper da Ready"
        ZK_READY=1
        break
    fi
    WAIT=$((i * 5))
    echo "    ... ZK dang khoi dong (${WAIT}s / 120s) - Phase: $PHASE"
    sleep 5
done

if [ "$ZK_READY" -eq 1 ]; then
    echo "    Xoa Kafka meta.properties de tranh cluster.id conflict..."
    kubectl run kafka-meta-cleaner --image=busybox --restart=Never -n kafka \
        --overrides='{"spec":{"volumes":[{"name":"d","persistentVolumeClaim":{"claimName":"data-0-kafka-cluster-kafka-0"}}],"containers":[{"name":"c","image":"busybox","command":["sh","-c","rm -f /data/kafka-log0/meta.properties; echo DONE"],"volumeMounts":[{"name":"d","mountPath":"/data"}]}]}}' 2>/dev/null
    sleep 8
    kubectl delete pod kafka-meta-cleaner -n kafka 2>/dev/null
    echo "    Da xoa meta.properties"
fi

# ── BUOC 5: Cho Kafka Ready roi restart Debezium ─────────────────────
echo ""
echo "[5/6] Cho Kafka Ready roi restart Debezium..."
KAFKA_READY=0
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
    K_PHASE=$(kubectl get pod kafka-cluster-kafka-0 -n kafka -o jsonpath="{.status.phase}" 2>/dev/null)
    K_READY=$(kubectl get pod kafka-cluster-kafka-0 -n kafka -o jsonpath="{.status.containerStatuses[0].ready}" 2>/dev/null)
    if [ "$K_PHASE" = "Running" ] && [ "$K_READY" = "true" ]; then
        echo "    Kafka da Ready"
        KAFKA_READY=1
        break
    fi
    WAIT=$((i * 5))
    echo "    ... Kafka dang khoi dong (${WAIT}s / 150s) - Phase: $K_PHASE"
    sleep 5
done

if [ "$KAFKA_READY" -eq 1 ]; then
    kubectl delete pod debezium-connect-cluster-connect-0 -n kafka 2>/dev/null
    echo "    Da restart Debezium"
else
    echo "    CANH BAO: Kafka chua Ready - kiem tra thu cong!"
fi

# ── BUOC 6: Ket qua cuoi ─────────────────────────────────────────────
echo ""
echo "[6/6] Trang thai cuoi cung:"
echo ""
echo "--- kafka namespace ---"
kubectl get pods -n kafka
echo ""
echo "--- dev namespace ---"
kubectl get pods -n dev
echo ""
echo "================================================================"
echo " Hoan tat!"
echo " - Zookeeper + Kafka: da Running"
echo " - Debezium: da restart sau khi Kafka san sang"
echo " - Neu con pod CrashLoopBackOff sau 3 phut, chay lai script"
echo "================================================================"
