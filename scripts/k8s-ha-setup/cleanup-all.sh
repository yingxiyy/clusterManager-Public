#!/usr/bin/env bash
# ==============================================================================
# Script: Complete Cleanup & Reset for K8s HA Environment
# Purpose: 彻底销毁 3 台虚拟机并清理宿主机残留，支持 100% 干净重试
# ==============================================================================
set -euo pipefail

echo "=================================================================="
echo "🧹 正在彻底清理并重置 Kubernetes HA 演练环境..."
echo "=================================================================="

# 0. 自动适配 multipass 执行身份（支持普通用户与 sudo 用户）
if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
    MP_CMD="sudo -u ${SUDO_USER} multipass"
else
    MP_CMD="multipass"
fi

# 1. 清理宿主机（物理机）上可能误启用的服务与端口
echo "==> [1/5] 清理物理宿主机残留服务 (haproxy/keepalived/kubelet) 与端口..."
sudo systemctl stop haproxy keepalived kubelet 2>/dev/null || true
sudo systemctl disable haproxy keepalived kubelet 2>/dev/null || true
sudo fuser -k 6443/tcp 2>/dev/null || true
sudo fuser -k 16443/tcp 2>/dev/null || true

# 2. 清理宿主机所有用户的 kubeconfig
echo "==> [2/5] 清理宿主机 kubeconfig 缓存 (~/.kube)..."
rm -rf "$HOME/.kube"
if [ -n "${SUDO_USER:-}" ]; then
    rm -rf "/home/${SUDO_USER}/.kube"
fi
rm -rf /root/.kube

# 3. 彻底停止并销毁所有 k8s 相关虚拟机 (包括 k8s-master-* 和 k8s-worker-*)
echo "==> [3/5] 探测并彻底停止所有 k8s 虚拟机..."
ALL_K8S_VMS=$(${MP_CMD} list 2>/dev/null | awk '/^k8s-/ {print $1}' || true)

if [ -n "${ALL_K8S_VMS}" ]; then
    for node in ${ALL_K8S_VMS}; do
        echo "  -> 强制停止虚拟机 [${node}]..."
        ${MP_CMD} stop --force "${node}" 2>/dev/null || true
        echo "  -> 删除虚拟机 [${node}]..."
        ${MP_CMD} delete --purge "${node}" 2>/dev/null || ${MP_CMD} delete "${node}" 2>/dev/null || true
    done
fi

# 备用容错：如果还有残留未知状态虚拟机，再次对默认命名的虚拟机执行强制清理
for node in k8s-master-01 k8s-master-02 k8s-master-03 k8s-worker-01 k8s-worker-02; do
    ${MP_CMD} stop --force "${node}" 2>/dev/null || true
    ${MP_CMD} delete --purge "${node}" 2>/dev/null || true
done

echo "==> [4/5] 彻底清除 Multipass 虚拟机回收站..."
${MP_CMD} purge 2>/dev/null || true

# 4. 验证清理结果
echo "==> [5/5] 验证当前虚拟机状态..."
${MP_CMD} list || true

echo "=================================================================="
echo "✨ 环境已彻底清空并重置完毕！所有 k8s-master 与 k8s-worker 节点已完全销毁。"
echo "👉 现在你可以严格按照《手册.md》从步骤 0 重新开始验证。"
echo "=================================================================="
