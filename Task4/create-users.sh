#!/bin/bash

# Скрипт для создания пользователей в Kubernetes
# Автор: Kubernetes RBAC Setup
# Версия: 1.0

set -e

echo "🚀 Создание пользователей для Kubernetes кластера..."

# Функция для создания пользователя с сертификатом
create_user() {
    local username=$1
    local group=$2
    
    echo "📝 Создание пользователя: $username (группа: $group)"
    
    # Создаем каталог для пользователя
    mkdir -p "./certs/$username"
    
    # Генерируем приватный ключ
    openssl genrsa -out "./certs/$username/$username.key" 2048
    
    # Создаем запрос на сертификат
    openssl req -new \
        -key "./certs/$username/$username.key" \
        -out "./certs/$username/$username.csr" \
        -subj "/CN=$username/O=$group"
    
    # Получаем CA сертификат и ключ из minikube
    MINIKUBE_CA_CERT=$(minikube ssh "sudo cat /var/lib/minikube/certs/ca.crt" 2>/dev/null || echo "")
    MINIKUBE_CA_KEY=$(minikube ssh "sudo cat /var/lib/minikube/certs/ca.key" 2>/dev/null || echo "")
    
    if [ -z "$MINIKUBE_CA_CERT" ] || [ -z "$MINIKUBE_CA_KEY" ]; then
        echo "❌ Не удалось получить CA сертификаты из minikube. Используем kubectl для создания CSR..."
        
        # Создаем CSR через kubectl
        kubectl apply -f - <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: $username-csr
spec:
  request: $(cat "./certs/$username/$username.csr" | base64 | tr -d '\n')
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
EOF
        
        # Одобряем CSR
        kubectl certificate approve "$username-csr"
        
        # Получаем подписанный сертификат
        kubectl get csr "$username-csr" -o jsonpath='{.status.certificate}' | base64 -d > "./certs/$username/$username.crt"
        
        # Удаляем CSR
        kubectl delete csr "$username-csr"
    else
        # Сохраняем CA сертификаты
        echo "$MINIKUBE_CA_CERT" > "./certs/ca.crt"
        echo "$MINIKUBE_CA_KEY" > "./certs/ca.key"
        
        # Подписываем сертификат
        openssl x509 -req \
            -in "./certs/$username/$username.csr" \
            -CA "./certs/ca.crt" \
            -CAkey "./certs/ca.key" \
            -CAcreateserial \
            -out "./certs/$username/$username.crt" \
            -days 365
    fi
    
    # Создаем kubeconfig для пользователя
    kubectl config set-cluster minikube-$username \
        --certificate-authority="$(pwd)/certs/ca.crt" \
        --server="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')" \
        --kubeconfig="./certs/$username/kubeconfig"
    
    kubectl config set-credentials $username \
        --client-certificate="$(pwd)/certs/$username/$username.crt" \
        --client-key="$(pwd)/certs/$username/$username.key" \
        --kubeconfig="./certs/$username/kubeconfig"
    
    kubectl config set-context $username-context \
        --cluster=minikube-$username \
        --user=$username \
        --kubeconfig="./certs/$username/kubeconfig"
    
    kubectl config use-context $username-context \
        --kubeconfig="./certs/$username/kubeconfig"
    
    echo "✅ Пользователь $username создан успешно"
}

# Создаем каталог для сертификатов
mkdir -p ./certs

echo "🔑 Создание пользователей..."

# Пользователь с правами администратора кластера
create_user "admin-user" "system:cluster-admins"

# Пользователь с правами только на просмотр
create_user "viewer-user" "system:viewers"

# Пользователь-разработчик
create_user "developer-user" "system:developers"

# Администратор namespace
create_user "namespace-admin-user" "system:namespace-admins"

# Дополнительный пользователь для тестирования
create_user "test-user" "system:testers"

echo ""
echo "🎉 Все пользователи созданы успешно!"
echo "📁 Сертификаты сохранены в директории ./certs/"
echo ""
echo "📋 Созданные пользователи:"
echo "  - admin-user (группа: system:cluster-admins)"
echo "  - viewer-user (группа: system:viewers)"
echo "  - developer-user (группа: system:developers)"
echo "  - namespace-admin-user (группа: system:namespace-admins)"
echo "  - test-user (группа: system:testers)"
echo ""
echo "🔧 Для использования kubeconfig пользователя:"
echo "export KUBECONFIG=\$(pwd)/certs/[username]/kubeconfig" 