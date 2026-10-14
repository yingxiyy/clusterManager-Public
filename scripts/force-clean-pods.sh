#!/usr/bin/env bash
# ==============================================================================
# 强制清理 Kubernetes 中卡在 Terminating / Pending 状态的 Pod
# 使用方法:
#   ./scripts/force-clean-pods.sh [namespace] (默认: data-platform)
# ==============================================================================
set -euo pipefail

# 自动探测与适配 KUBECONFIG（即使加了 sudo 也能自动使用 sysadmin 的配置）
if [ -z "${KUBECONFIG:-}" ]; then
  if [ -n "${SUDO_USER:-}" ] && [ -f "/home/${SUDO_USER}/.kube/config" ]; then
    export KUBECONFIG="/home/${SUDO_USER}/.kube/config"
  elif [ -f "${HOME}/.kube/config" ]; then
    export KUBECONFIG="${HOME}/.kube/config"
  fi
fi

NS="${1:-data-platform}"

echo "=================================================================="
echo " 正在强制清理命名空间 [${NS}] 中卡住的 Terminating Pod..."
echo " 使用的 Kubeconfig: ${KUBECONFIG:-~/.kube/config}"
echo "=================================================================="

# 验证 kubectl 是否可连通集群
if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "❌ 错误: 当前用户无法连接到 Kubernetes 集群。请检查 KUBECONFIG 或不要使用 sudo。"
  exit 1
fi

# 获取所有处于 Terminating 状态的 Pod
TERMINATING_PODS=$(kubectl get pods -n "${NS}" --no-headers 2>/dev/null | grep 'Terminating' | awk '{print $1}' || true)

if [ -z "${TERMINATING_PODS}" ]; then
  echo "--> 没有发现状态为 Terminating 的 Pod。"
else
  for pod in ${TERMINATING_PODS}; do
    echo "--> 正在强制清除 Pod: ${pod}"
    # 移除 Finalizers 阻止卷卸载挂起（两种方式双保险）
    kubectl patch pod "${pod}" -n "${NS}" -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
    kubectl patch pod "${pod}" -n "${NS}" --type=json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' 2>/dev/null || true
    # 强制以 0 宽限期删除
    kubectl delete pod "${pod}" -n "${NS}" --force --grace-period=0 2>/dev/null || true
  done
  echo "--> Terminating Pod 强制清理指令已下发！"
fi

echo ""
echo "--> 当前 ${NS} 命名空间下的 Pod 状态:"
kubectl get pods -n "${NS}"
