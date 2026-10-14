#!/usr/bin/env bash
# ==============================================================================
# 强制清理 Kubernetes 中卡在 Terminating / Pending 状态的 Pod
# 使用方法:
#   ./scripts/force-clean-pods.sh [namespace] (默认: data-platform)
# ==============================================================================
set -euo pipefail

NS="${1:-data-platform}"

echo "=================================================================="
echo " 正在强制清理命名空间 [${NS}] 中卡住的 Terminating Pod..."
echo "=================================================================="

# 获取所有处于 Terminating 状态的 Pod
TERMINATING_PODS=$(kubectl get pods -n "${NS}" --no-headers 2>/dev/null | grep 'Terminating' | awk '{print $1}' || true)

if [ -z "${TERMINATING_PODS}" ]; then
  echo "--> 没有发现卡在 Terminating 状态的 Pod。"
else
  for pod in ${TERMINATING_PODS}; do
    echo "--> 处理 Pod: ${pod}"
    # 移除 Finalizers 避免被底层卷或钩子卡住
    kubectl patch pod "${pod}" -n "${NS}" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
    # 强制以 0 宽限期删除
    kubectl delete pod "${pod}" -n "${NS}" --force --grace-period=0 2>/dev/null || true
  done
  echo "--> Terminating Pod 清理完毕！"
fi

echo ""
echo "--> 当前 ${NS} 命名空间下的 Pod 状态:"
kubectl get pods -n "${NS}"
