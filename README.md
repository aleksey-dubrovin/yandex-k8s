# Развёртывание MicroK8S в Yandex Cloud (Terraform)

Этот репозиторий содержит конфигурации Terraform для создания виртуальной машины в Yandex Cloud с предустановленным MicroK8S.

После выполнения `terraform apply` вам нужно вручную выполнить несколько шагов, чтобы получить доступ к кластеру и Dashboard.

## Предварительные требования

- Установленный Terraform (>= 1.0)
- SSH-ключи (публичный и приватный). По умолчанию ожидается `~/.ssh/rsa_id.pub` (можно изменить в `variables.tf`).
- OAuth-токен, cloud_id и folder_id Yandex Cloud.

## Быстрый старт

1. Склонируйте репозиторий и перейдите в папку с файлами.

2. Создайте `terraform.tfvars`:
   ```hcl
   yandex_cloud_token = "ваш_oauth_токен"
   cloud_id           = "ваш_cloud_id"
   folder_id          = "ваш_folder_id"
   ```

3. Выполните:
   ```bash
   terraform init
   terraform apply -auto-approve
   ```

   После завершения вы увидите внешний IP виртуальной машины.

4. Подключитесь к ВМ по SSH:
   ```bash
   ssh ubuntu@<внешний_IP>
   ```

5. Прверьте логи cliud_init на наличе ошибок:
   ```bash
   cat /var/log/cloud-init-output.log
   ```

## Ручная настройка после установки

### 1. Проверьте, что MicroK8S работает

```bash
sudo microk8s status --wait-ready
sudo microk8s kubectl get nodes
```

### 2. Установите Kubernetes Dashboard (если не включился автоматически)

```bash
sudo microk8s enable dashboard -r https://kubernetes-retired.github.io/dashboard/
```

### 3. Переключите Dashboard на NodePort

```bash
sudo microk8s kubectl patch svc kubernetes-dashboard-kong-proxy -n kubernetes-dashboard -p '{"spec": {"type": "NodePort"}}'
```

Узнайте назначенный порт:

```bash
sudo microk8s kubectl get svc kubernetes-dashboard-kong-proxy -n kubernetes-dashboard
```

В строке `kubernetes-dashboard` в колонке `PORT(S)` будет `443:3XXXX/TCP` (например `30154`). Запомните этот порт.

### 4. Создайте пользователя-администратора и получите токен для Dashboard

```bash
cat <<EOF | sudo microk8s kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF

sudo microk8s kubectl -n kubernetes-dashboard create token admin-user
```

Скопируйте длинный токен — он понадобится для входа.

### 5. Откройте Dashboard в браузере

Перейдите по адресу:
```
https://<внешний_IP_ВМ>:<порт_из_шага_3>
```

Браузер покажет предупреждение о сертификате — нажмите «Принять риск» / «Продолжить». Выберите вход **Token**, вставьте скопированный токен.

### 6. Настройте локальный kubectl (со своего компьютера)

#### 6.1 Установите kubectl, если ещё не установлен

**Linux (Ubuntu/Debian):**
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

# Автодополнение (по желанию)
source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> ~/.bashrc
```

**macOS:** `brew install kubectl`  
**Windows:** скачайте `kubectl.exe` из релизов Kubernetes.
**Подробнее:** https://kubernetes.io/ru/docs/tasks/tools/install-kubectl/

#### 6.2 Получите токен для kubectl (можно использовать тот же, что для Dashboard)

На ВМ выполните:
```bash
sudo microk8s kubectl -n kubernetes-dashboard create token admin-user --duration=8760h
```

Скопируйте полученный токен.

#### 6.3 Настройте контекст kubectl на локальной машине

```bash
kubectl config set-cluster microk8s --server=https://<внешний_IP_ВМ>:16443 --insecure-skip-tls-verify
kubectl config set-credentials admin --token="<ваш_токен>"
kubectl config set-context microk8s --cluster=microk8s --user=admin
kubectl config use-context microk8s
```

#### 6.4 Проверьте подключение

```bash
kubectl get nodes
kubectl get pods -A
```

Вы должны увидеть свою ноду в статусе `Ready`.

## Возможные проблемы и решения

| Проблема | Решение |
|----------|---------|
| `microk8s enable dashboard` выдаёт 404 | Установите dashboard вручную командой из шага 2. |
| Dashboard не открывается в браузере | Убедитесь, что порт (30000-32767) не блокируется фаерволом. В `main.tf` уже открыт диапазон портов. Также проверьте, что сервис переключён на NodePort. |
| `kubectl get nodes` выдаёт `connection refused` | Убедитесь, что порт 16443 открыт (в `main.tf` есть правило). На ВМ перезапустите API-сервер: `sudo systemctl restart snap.microk8s.daemon-kubelite.service`. |
| Ошибка сертификата при использовании kubectl | Используйте флаг `--insecure-skip-tls-verify` (он уже добавлен в команду `set-cluster`). |

## Итог

После выполнения всех шагов вы получите рабочий Kubernetes-кластер, доступный через `kubectl` с локальной машины, и веб-интерфейс Dashboard для мониторинга.