#!/usr/bin/env bash
# ==============================================================================
# Script: Complete Cleanup & Reset for K8s HA Environment
# Purpose: 彻底销毁 3 台虚拟机并清理宿主机残留，支持 100% 干净重试
# ==============================================================================
set -euo pipefail

echo "=================================================================="
echo "🧹 正在彻底清理并重置 Kubernetes HA 演练环境..."
echo "=================================================================="

# 1. 清理宿主机（物理机）上可能误启用的服务与端口
echo "==> [1/4] 清理物理宿主机残留服务 (haproxy/keepalived/kubelet)..."
sudo systemctl stop haproxy keepalived kubelet 2>/dev/null || true
sudo systemctl disable haproxy keepalived kubelet 2>/dev/null || true
sudo fuser -k 6443/tcp 2>/dev/null || true
sudo fuser -k 16443/tcp 2>/dev/null || true

# 2. 清理宿主机 kubeconfig
echo "==> [2/4] 清理宿主机 kubeconfig 缓存 (~/.kube)..."
rm -rf "$HOME/.kube"

# 3. 停止并彻底销毁 3 台 Multipass 虚拟机
echo "==> [3/4] 停止并删除 3 台虚拟机 (k8s-master-01, 02, 03)..."
multipass stop k8s-master-01 k8s-master-02 k8s-master-03 2>/dev/null || true
multipass delete k8s-master-01 k8s-master-02 k8s-master-03 2>/dev/null || true
multipass purge 2>/dev/null || true

# 4. 验证清理结果
echo "==> [4/4] 验证当前虚拟机状态..."
multipass list

echo "=================================================================="
echo "✨ 环境已彻底清空并重置完毕！"
echo "👉 现在你可以严格按照《手册.md》从步骤 0 重新开始验证。"
echo "=================================================================="
