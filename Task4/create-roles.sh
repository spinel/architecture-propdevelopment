#!/bin/bash

# Скрипт для создания ролей в Kubernetes
# Автор: Kubernetes RBAC Setup
# Версия: 1.0

set -e

echo "🚀 Создание ролей для Kubernetes кластера..."

# Функция для создания ClusterRole
create_cluster_role() {
    local role_name=$1
    local role_file=$2
    
    echo "📝 Создание ClusterRole: $role_name"
    kubectl apply -f "$role_file"
    echo "✅ ClusterRole $role_name создана успешно"
}

# Функция для создания Role в namespace
create_namespace_role() {
    local role_name=$1
    local namespace=$2
    local role_file=$3
    
    echo "📝 Создание Role: $role_name в namespace: $namespace"
    kubectl apply -f "$role_file"
    echo "✅ Role $role_name создана успешно в namespace $namespace"
}

echo "🔧 Создание ClusterRoles..."

# 1. Cluster Admin Role - полный доступ ко всем ресурсам
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-admin-role
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
- nonResourceURLs: ["*"]
  verbs: ["*"]
EOF
echo "✅ ClusterRole cluster-admin-role создана"

# 2. Viewer Role - только чтение ресурсов (кроме секретов)
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: viewer-role
rules:
# Базовые ресурсы для чтения
- apiGroups: [""]
  resources: ["pods", "pods/log", "pods/status", "services", "endpoints", "persistentvolumeclaims", "configmaps", "nodes", "namespaces"]
  verbs: ["get", "list", "watch"]
# Apps API группа
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "daemonsets", "statefulsets"]
  verbs: ["get", "list", "watch"]
# Extensions API группа
- apiGroups: ["extensions"]
  resources: ["deployments", "replicasets", "daemonsets"]
  verbs: ["get", "list", "watch"]
# Networking
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses", "networkpolicies"]
  verbs: ["get", "list", "watch"]
# Autoscaling
- apiGroups: ["autoscaling"]
  resources: ["horizontalpodautoscalers"]
  verbs: ["get", "list", "watch"]
# Metrics
- apiGroups: ["metrics.k8s.io"]
  resources: ["pods", "nodes"]
  verbs: ["get", "list"]
EOF
echo "✅ ClusterRole viewer-role создана"

# 3. Developer Role - управление ресурсами в namespace (кроме секретов и RBAC)
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: developer-role
rules:
# Базовые ресурсы для разработки
- apiGroups: [""]
  resources: ["pods", "pods/log", "pods/exec", "pods/portforward", "services", "endpoints", "persistentvolumeclaims", "configmaps"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
# Apps API группа
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "daemonsets", "statefulsets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
# Extensions API группа
- apiGroups: ["extensions"]
  resources: ["deployments", "replicasets", "daemonsets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
# Batch API группа
- apiGroups: ["batch"]
  resources: ["jobs", "cronjobs"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
# Networking
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
# Autoscaling
- apiGroups: ["autoscaling"]
  resources: ["horizontalpodautoscalers"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
# Чтение namespace и nodes
- apiGroups: [""]
  resources: ["namespaces", "nodes"]
  verbs: ["get", "list", "watch"]
# Metrics для мониторинга
- apiGroups: ["metrics.k8s.io"]
  resources: ["pods", "nodes"]
  verbs: ["get", "list"]
EOF
echo "✅ ClusterRole developer-role создана"

# 4. Namespace Admin Role - полный доступ в рамках namespace
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: namespace-admin-role
rules:
# Полный доступ ко всем ресурсам в namespace
- apiGroups: [""]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: ["apps"]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: ["extensions"]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: ["batch"]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: ["networking.k8s.io"]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: ["autoscaling"]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["roles", "rolebindings"]
  verbs: ["*"]
# Чтение на уровне кластера
- apiGroups: [""]
  resources: ["namespaces", "nodes"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["metrics.k8s.io"]
  resources: ["pods", "nodes"]
  verbs: ["get", "list"]
EOF
echo "✅ ClusterRole namespace-admin-role создана"

echo ""
echo "🎯 Создание специальных namespace для демонстрации..."

# Создаем тестовые namespace
kubectl create namespace development --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace staging --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace production --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Namespace development, staging, production созданы"

echo ""
echo "🎉 Все роли созданы успешно!"
echo ""
echo "📋 Созданные ClusterRoles:"
echo "  - cluster-admin-role (полный доступ к кластеру)"
echo "  - viewer-role (только чтение ресурсов)"
echo "  - developer-role (управление ресурсами в namespace)"
echo "  - namespace-admin-role (администрирование namespace)"
echo ""
echo "📁 Созданные namespace для тестирования:"
echo "  - development"
echo "  - staging" 
echo "  - production"
echo ""
echo "🔧 Для просмотра созданных ролей:"
echo "kubectl get clusterroles | grep -E '(cluster-admin-role|viewer-role|developer-role|namespace-admin-role)'" 