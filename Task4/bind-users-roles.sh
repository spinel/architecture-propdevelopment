#!/bin/bash

# Скрипт для связывания пользователей с ролями в Kubernetes
# Автор: Kubernetes RBAC Setup
# Версия: 1.0

set -e

echo "🚀 Связывание пользователей с ролями в Kubernetes кластере..."

# Функция для создания ClusterRoleBinding
create_cluster_role_binding() {
    local binding_name=$1
    local role_name=$2
    local user_name=$3
    local group_name=$4
    
    echo "📝 Создание ClusterRoleBinding: $binding_name"
    
    if [ -n "$user_name" ]; then
        # Привязка для конкретного пользователя
        cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: $binding_name
subjects:
- kind: User
  name: $user_name
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: $role_name
  apiGroup: rbac.authorization.k8s.io
EOF
    else
        # Привязка для группы
        cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: $binding_name
subjects:
- kind: Group
  name: $group_name
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: $role_name
  apiGroup: rbac.authorization.k8s.io
EOF
    fi
    
    echo "✅ ClusterRoleBinding $binding_name создан"
}

# Функция для создания RoleBinding в namespace
create_role_binding() {
    local binding_name=$1
    local role_name=$2
    local namespace=$3
    local user_name=$4
    local group_name=$5
    
    echo "📝 Создание RoleBinding: $binding_name в namespace: $namespace"
    
    if [ -n "$user_name" ]; then
        # Привязка для конкретного пользователя
        cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  namespace: $namespace
  name: $binding_name
subjects:
- kind: User
  name: $user_name
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: $role_name
  apiGroup: rbac.authorization.k8s.io
EOF
    else
        # Привязка для группы
        cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  namespace: $namespace
  name: $binding_name
subjects:
- kind: Group
  name: $group_name
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: $role_name
  apiGroup: rbac.authorization.k8s.io
EOF
    fi
    
    echo "✅ RoleBinding $binding_name создан в namespace $namespace"
}

echo "🔧 Создание привязок пользователей к ролям..."

# 1. Привязка администратора кластера
echo "👑 Настройка прав администратора кластера..."
create_cluster_role_binding "cluster-admin-binding" "cluster-admin-role" "admin-user" ""
create_cluster_role_binding "cluster-admin-group-binding" "cluster-admin-role" "" "system:cluster-admins"

# 2. Привязка пользователей с правами только на просмотр
echo "👀 Настройка прав для просмотра..."
create_cluster_role_binding "viewer-binding" "viewer-role" "viewer-user" ""
create_cluster_role_binding "viewer-group-binding" "viewer-role" "" "system:viewers"

# 3. Привязка разработчиков к namespace
echo "💻 Настройка прав разработчиков..."
# Разработчики имеют доступ к development и staging namespace
create_role_binding "developer-development-binding" "developer-role" "development" "developer-user" ""
create_role_binding "developer-staging-binding" "developer-role" "staging" "developer-user" ""
create_role_binding "developer-group-development-binding" "developer-role" "development" "" "system:developers"
create_role_binding "developer-group-staging-binding" "developer-role" "staging" "" "system:developers"

# 4. Привязка администраторов namespace
echo "🏗️ Настройка прав администраторов namespace..."
# Администратор namespace имеет полные права в production
create_role_binding "namespace-admin-production-binding" "namespace-admin-role" "production" "namespace-admin-user" ""
create_role_binding "namespace-admin-group-production-binding" "namespace-admin-role" "production" "" "system:namespace-admins"

# Администратор namespace также имеет права в development для управления
create_role_binding "namespace-admin-development-binding" "namespace-admin-role" "development" "namespace-admin-user" ""

# 5. Дополнительные привязки для тестового пользователя
echo "🧪 Настройка прав тестового пользователя..."
# Тестовый пользователь имеет права просмотра на уровне кластера
create_cluster_role_binding "test-viewer-binding" "viewer-role" "test-user" ""
# И права разработчика в development namespace
create_role_binding "test-developer-binding" "developer-role" "development" "test-user" ""

echo ""
echo "🎯 Создание дополнительных демонстрационных объектов..."

# Создаем тестовые ресурсы для демонстрации
kubectl create secret generic test-secret --from-literal=password=super-secret -n development --dry-run=client -o yaml | kubectl apply -f -
kubectl create configmap test-config --from-literal=config=test-value -n development --dry-run=client -o yaml | kubectl apply -f -

# Создаем простой deployment для тестирования
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
  namespace: development
  labels:
    app: test-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
EOF

echo ""
echo "🎉 Все привязки созданы успешно!"
echo ""
echo "📋 Созданные привязки:"
echo ""
echo "🌐 ClusterRoleBindings (доступ на уровне кластера):"
echo "  - cluster-admin-binding: admin-user → cluster-admin-role"
echo "  - cluster-admin-group-binding: system:cluster-admins → cluster-admin-role"
echo "  - viewer-binding: viewer-user → viewer-role"
echo "  - viewer-group-binding: system:viewers → viewer-role"
echo "  - test-viewer-binding: test-user → viewer-role"
echo ""
echo "📁 RoleBindings (доступ в namespace):"
echo "  Development namespace:"
echo "    - developer-development-binding: developer-user → developer-role"
echo "    - developer-group-development-binding: system:developers → developer-role"
echo "    - namespace-admin-development-binding: namespace-admin-user → namespace-admin-role"
echo "    - test-developer-binding: test-user → developer-role"
echo ""
echo "  Staging namespace:"
echo "    - developer-staging-binding: developer-user → developer-role"
echo "    - developer-group-staging-binding: system:developers → developer-role"
echo ""
echo "  Production namespace:"
echo "    - namespace-admin-production-binding: namespace-admin-user → namespace-admin-role"
echo "    - namespace-admin-group-production-binding: system:namespace-admins → namespace-admin-role"
echo ""
echo "🔧 Команды для проверки доступа:"
echo "# Проверка прав пользователя:"
echo "kubectl auth can-i --list --as=developer-user"
echo ""
echo "# Проверка доступа к секретам:"
echo "kubectl auth can-i get secrets --as=viewer-user"
echo "kubectl auth can-i get secrets --as=admin-user"
echo ""
echo "# Проверка доступа к namespace:"
echo "kubectl auth can-i get pods -n development --as=developer-user"
echo "kubectl auth can-i get pods -n production --as=developer-user"
echo ""
echo "# Использование kubeconfig пользователя:"
echo "export KUBECONFIG=\$(pwd)/certs/[username]/kubeconfig"
echo "kubectl get pods -n development" 