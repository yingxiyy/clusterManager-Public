#!/usr/bin/env bash
# ==============================================================================
# Deploy CloudCluster Helm Chart with Custom Values & Extensions
# Usage: ./scripts/helm-install.sh [NAMESPACE] [RELEASE_NAME] [VALUES_OVERRIDE_FILE]
# ==============================================================================
set -euo pipefail

NAMESPACE="${1:-data-platform}"
RELEASE_NAME="${2:-cloudcluster}"
VALUES_FILE="${3:-helm/values.yaml}"
CREDENTIALS_OVERRIDE="helm/custom-credentials.yaml"

# Auto-detect KUBECONFIG if running under sudo or standard user
if [ -z "${KUBECONFIG:-}" ]; then
  if [ -f "${HOME}/.kube/config" ]; then
    export KUBECONFIG="${HOME}/.kube/config"
  elif [ -n "${SUDO_USER:-}" ] && [ -f "/home/${SUDO_USER}/.kube/config" ]; then
    export KUBECONFIG="/home/${SUDO_USER}/.kube/config"
    echo "--> Detected sudo execution, automatically using KUBECONFIG from: ${KUBECONFIG}"
  fi
fi

# Pre-flight helm tool check
if ! command -v helm >/dev/null 2>&1; then
  echo "======================================================================"
  echo "❌ 宿主机未检测到 helm 命令行工具！"
  echo "======================================================================"
  echo "请在物理宿主机终端运行以下命令快速安装 Helm (v3)："
  echo ""
  echo "  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
  echo ""
  echo "或者使用 snap 安装："
  echo "  sudo snap install helm --classic"
  echo ""
  echo "如果国内无法直连 GitHub，可使用官方二进制包或国内镜像加速："
  echo "  curl -fsSL https://get.helm.sh/helm-v3.14.4-linux-amd64.tar.gz -o /tmp/helm.tar.gz"
  echo "  tar -zxvf /tmp/helm.tar.gz -C /tmp && sudo mv /tmp/linux-amd64/helm /usr/local/bin/helm"
  echo "======================================================================"
  exit 1
fi

# Pre-flight cluster connection verification
if ! kubectl cluster-info >/dev/null 2>&1 && ! kubectl get nodes >/dev/null 2>&1; then
  echo "======================================================================"
  echo "❌ 无法连接到 Kubernetes 集群！"
  echo "======================================================================"
  echo "可能的原因："
  echo "1. 物理机尚未配置 ~/.kube/config 凭据。"
  echo "   请先在物理机执行："
  echo "     mkdir -p \$HOME/.kube"
  echo "     multipass exec k8s-master-01 -- sudo cat /etc/kubernetes/admin.conf > \$HOME/.kube/config"
  echo "     chmod 600 \$HOME/.kube/config"
  echo "     kubectl get nodes -o wide"
  echo ""
  echo "2. 如果您使用了 'sudo ./scripts/helm-install.sh'："
  echo "   helm 与 kubectl 不需要 sudo 权限，建议直接以普通用户执行："
  echo "     ./scripts/helm-install.sh"
  echo "======================================================================"
  exit 1
fi

# Auto-initialize credentials if not already provisioned
if [ ! -f "${CREDENTIALS_OVERRIDE}" ] && [ -f "scripts/init-credentials.sh" ]; then
  echo "--> Initial credentials not found. Generating default secure credentials..."
  bash scripts/init-credentials.sh
fi

EXTRA_VALUES_ARGS=()
if [ -f "${CREDENTIALS_OVERRIDE}" ]; then
  EXTRA_VALUES_ARGS+=(-f "${CREDENTIALS_OVERRIDE}")
  echo "--> Loaded custom authentication credentials from: ${CREDENTIALS_OVERRIDE}"
fi

# Support IMAGE_REGISTRY environment variable to override mirror/registry dynamically
if [ -n "${IMAGE_REGISTRY:-}" ]; then
  EXTRA_VALUES_ARGS+=(--set "global.imageRegistry=${IMAGE_REGISTRY}")
  echo "--> 镜像仓库前缀生效: ${IMAGE_REGISTRY} (覆盖 global.imageRegistry)"
fi

echo "======================================================================"
echo " Deploying CloudCluster Helm Stack"
echo " Namespace: ${NAMESPACE}"
echo " Release:   ${RELEASE_NAME}"
echo " Values:    ${VALUES_FILE}"
echo "======================================================================"

# Auto-ensure control plane nodes are untainted so pods can run on 3-master topology
kubectl taint nodes --all node-role.kubernetes.io/control-plane- 2>/dev/null || true
kubectl taint nodes --all node-role.kubernetes.io/master- 2>/dev/null || true

# Auto-ensure dynamic storage class is available
if ! kubectl get storageclass >/dev/null 2>&1 || [ -z "$(kubectl get storageclass -o name 2>/dev/null)" ]; then
  echo "--> 集群尚未检测到 StorageClass 存储类，自动部署 local-path-storage 提供本地持久卷..."
  if [ -f "scripts/k8s-ha-setup/local-path-storage.yaml" ]; then
    kubectl apply -f scripts/k8s-ha-setup/local-path-storage.yaml
    echo "--> StorageClass 部署完成。"
  fi
fi

# Ensure namespace exists without pipe openapi validation issues
if ! kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
  echo "--> Creating namespace ${NAMESPACE}..."
  kubectl create namespace "${NAMESPACE}"
fi

HELM_EXTRA_FLAGS=()
if [ "${4:-}" = "--wait" ]; then
  HELM_EXTRA_FLAGS+=(--wait --timeout 15m)
fi

echo "--> 正在向 Kubernetes 提交 Helm Chart 配置..."
helm upgrade --install "${RELEASE_NAME}" ./helm \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  -f "${VALUES_FILE}" \
  "${EXTRA_VALUES_ARGS[@]}" \
  --no-hooks \
  "${HELM_EXTRA_FLAGS[@]}"

echo "======================================================================"
echo " 🎉 Helm Stack 资源已成功下发至集群！"
echo " 当前 data-platform 命名空间下的 Pod 与存储卷 (PVC) 状态如下："
echo "======================================================================"
kubectl get pods,pvc -n "${NAMESPACE}" -o wide
echo ""
echo "💡 提示：镜像拉取与组件初始化通常需要 1~3 分钟，您可运行以下命令实时追踪进度："
echo "   kubectl get pods -n ${NAMESPACE} -w"

