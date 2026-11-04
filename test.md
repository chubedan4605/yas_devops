Ran check storageClass requirements
Ran read k8s/namespaces.yaml
Ran read cluster-config.yaml
Analyzed run-yas-setup.ps1:L80-180
Analyzed run-yas-setup.ps1:L181-300

Tuyệt vời! Trong lúc chờ lệnh `minikube start --nodes 2 --memory 12288 --cpus 4` tải image và khởi động cụm xong (mất khoảng 2–4 phút), đây là **toàn bộ lộ trình các bước tiếp theo** để bạn thiết lập hoàn chỉnh hệ thống:

---

### BƯỚC 1: Kiểm tra Cụm 2 Node & Bật Addon thiết yếu
Ngay khi lệnh `minikube start` hoàn tất và trả về dấu nhắc lệnh, bạn gõ:

```powershell
# 1. Kiểm tra 2 node đã Ready chưa
kubectl get nodes

# 2. Bật Ingress Controller và Metrics Server của Minikube
minikube addons enable ingress
minikube addons enable metrics-server
```
*(Bạn sẽ thấy 2 node: `minikube` đóng vai trò Master/Control-plane và `minikube-m02` đóng vai trò Worker).*

---

### BƯỚC 2: Gỡ Taint và Gán nhãn cho 2 Node (Bắt buộc)
Các Helm chart của dự án phân chia tải: Pod nặng (Database, Kafka, Backend) chạy trên node `type=heavy`, Pod giao diện nhẹ (UI) chạy trên node `type=light`.

Chạy các lệnh sau:
```powershell
# Cho phép Node Master nhận chạy pod ứng dụng (gỡ NoSchedule)
kubectl taint nodes minikube node-role.kubernetes.io/control-plane:NoSchedule- 2>$null
kubectl taint nodes minikube node-role.kubernetes.io/master:NoSchedule- 2>$null

# Gán nhãn cho Master là 'heavy', Worker là 'light'
kubectl label node minikube type=heavy --overwrite
kubectl label node minikube-m02 type=light --overwrite
```

---

### BƯỚC 3: Lấy IP Minikube và cập nhật file `hosts`
1. Lấy địa chỉ IP của Minikube:
   ```powershell
   minikube ip
   ```
   *(Thường sẽ in ra IP dạng `192.168.49.2`)*.

2. Mở file `C:\Windows\System32\drivers\etc\hosts` bằng **Notepad (Run as Administrator)** và thêm đoạn sau vào cuối file (thay `192.168.49.2` bằng IP thực tế vừa in ra):
   ```text
   192.168.49.2  api.yas.local
   192.168.49.2  storefront.yas.local
   192.168.49.2  backoffice.yas.local
   192.168.49.2  identity.yas.local.com
   192.168.49.2  grafana.yas.local.com
   192.168.49.2  kiali.yas.local.com
   192.168.49.2  argocd.yas.local.com
   ```
   Lưu file lại (`Ctrl + S`).

---

### BƯỚC 4: Tạo các Namespace dự án
```powershell
kubectl apply -f k8s/namespaces.yaml
```
*Lệnh này sẽ tạo sẵn các namespace `dev`, `staging`, `developer-sandbox` và bật sẵn cờ tự động gắn sidecar `istio-injection: enabled`.*

---

### BƯỚC 5: Cài đặt Hạ tầng nền tảng (Database, Keycloak, Kafka, ArgoCD, Istio)
Thêm các kho Helm cần thiết:
```powershell
helm repo add postgres-operator-charts https://opensource.zalando.com/postgres-operator/charts/postgres-operator
helm repo add strimzi https://strimzi.io/charts/
helm repo add akhq https://akhq.io/
helm repo add elastic https://helm.elastic.co
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add stakater https://stakater.github.io/stakater-charts
helm repo update
```

Sau đó cài đặt lần lượt:
```powershell
# 1. Cài Redis
helm upgrade --install redis bitnami/redis --create-namespace --namespace redis --set auth.password="redis"

# 2. Cài Postgres Operator & Postgres Database
helm upgrade --install postgres-operator postgres-operator-charts/postgres-operator --create-namespace --namespace postgres
Start-Sleep -Seconds 15
helm upgrade --install postgres k8s/deploy/postgres/postgresql --create-namespace --namespace postgres --set replicas=1 --set username="yasadminuser" --set password="admin"

# 3. Cài Keycloak Operator & Keycloak
kubectl create namespace keycloak 2>$null
kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/26.0.2/kubernetes/keycloaks.k8s.keycloak.org-v1.yml
kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/26.0.2/kubernetes/keycloakrealmimports.k8s.keycloak.org-v1.yml
kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/26.0.2/kubernetes/kubernetes.yml -n keycloak
helm upgrade --install keycloak k8s/deploy/keycloak/keycloak --namespace keycloak --set hostname="identity.yas.local.com" --set postgresql.username="yasadminuser" --set postgresql.password="admin"

# 4. Cài Kafka (Strimzi)
helm upgrade --install kafka-operator strimzi/strimzi-kafka-operator --create-namespace --namespace kafka --version 0.43.0
Start-Sleep -Seconds 20
helm upgrade --install kafka-cluster k8s/deploy/kafka/kafka-cluster --create-namespace --namespace kafka --set kafka.replicas=1 --set zookeeper.replicas=1

# 5. Cài ArgoCD & Bootstrap GitOps
kubectl create namespace argocd 2>$null
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.12.0/manifests/install.yaml
kubectl apply -f argocd/yas-dev-bootstrap.yaml
kubectl apply -f argocd/yas-staging-bootstrap.yaml
```

---

### BƯỚC 6: Khởi chạy Jenkins CI/CD
1. Lấy file Kubeconfig của Minikube copy vào Jenkins:
   ```powershell
   Copy-Item "$env:USERPROFILE\.kube\config" "docker-jenkins\kubeconfig-docker" -Force
   ```
2. Khởi động container Jenkins:
   ```powershell
   cd docker-jenkins
   docker compose up -d --build
   cd ..
   ```
3. Mở trình duyệt vào **`http://localhost:8899`**, thêm 2 credentials:
   * **`github-credentials`**: GitHub Username + Personal Access Token.
   * **`dockerhub-credentials`**: `chubedan4605` + Mật khẩu/Token Docker Hub.

---

Khi lệnh `minikube start` chạy xong, bạn cứ chạy tiếp **BƯỚC 1 và BƯỚC 2**. Nếu có bất kỳ thông báo gì trên màn hình, hãy dán vào đây mình sẽ hướng dẫn tiếp nhé!