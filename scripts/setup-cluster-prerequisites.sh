#!/usr/bin/env bash
# ==============================================================================
# Script: Setup Cluster Prerequisites (Untaint Nodes, StorageClass, Containerd Mirrors)
# Run from Physical Host where kubectl & multipass are accessible
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_SETUP_DIR="${SCRIPT_DIR}/k8s-ha-setup"

echo "======================================================================"
echo " 🛠️  K8s 集群前置就绪准备 (污点清除 / 动态存储卷 / 国内镜像加速)"
echo "======================================================================"

# 0. 自动适配与继承 KUBECONFIG（即使加了 sudo 也能自动使用 sysadmin 的凭据）
if [ -z "${KUBECONFIG:-}" ]; then
  if [ -n "${SUDO_USER:-}" ] && [ -f "/home/${SUDO_USER}/.kube/config" ]; then
    export KUBECONFIG="/home/${SUDO_USER}/.kube/config"
  elif [ -f "${HOME}/.kube/config" ]; then
    export KUBECONFIG="${HOME}/.kube/config"
  elif [ -f "/root/.kube/config" ]; then
    export KUBECONFIG="/root/.kube/config"
  fi
fi

# 1. 验证 kubectl 连接
if ! kubectl cluster-info >/dev/null 2>&1 && ! kubectl get nodes >/dev/null 2>&1; then
  echo "❌ 无法通过 kubectl 连接集群！"
  echo ""
  echo "👉 请排查以下原因："
  echo "   1) 是否尚未执行《手册.md》的【步骤 3】将虚拟机凭据同步到物理机？"
  echo "      请在宿主机终端执行以下命令拉取凭据："
  echo "      mkdir -p \$HOME/.kube"
  echo "      multipass exec k8s-master-01 -- sudo cat /etc/kubernetes/admin.conf > \$HOME/.kube/config"
  echo "      chmod 600 \$HOME/.kube/config"
  echo ""
  echo "   2) 如果你刚刚执行了【步骤 0】（创建虚拟机），请务必依次执行："
  echo "      • 步骤 1：在 3 台虚拟机内启动 HAProxy + Keepalived 高可用"
  echo "      • 步骤 2：在 k8s-master-01 上初始化集群并 join 其余 master"
  echo "      • 步骤 3：拉取凭据（如上所示）"
  echo "      • 步骤 4：然后再执行本脚本部署存储与镜像加速！"
  exit 1
fi

echo "--> [1/3] 清除所有 Master 节点的调度污点 (允许工作负载调度)..."
kubectl taint nodes --all node-role.kubernetes.io/control-plane- 2>/dev/null || true
kubectl taint nodes --all node-role.kubernetes.io/master- 2>/dev/null || true
echo "✅ 所有 Master 节点已解除调度限制。"

echo "--> [2/3] 部署轻量级本地动态存储卷 (local-path-provisioner)..."
kubectl apply -f "${K8S_SETUP_DIR}/local-path-storage.yaml"
echo "✅ 动态 StorageClass (standard, local-storage, local-path) 已部署！"

echo "--> [3/3] 配置 3 台 Multipass 虚拟机内 containerd 的国内镜像加速..."
VMS=("k8s-master-01" "k8s-master-02" "k8s-master-03")

for vm in "${VMS[@]}"; do
  if multipass info "${vm}" >/dev/null 2>&1; then
    echo "  -> 正在为 ${vm} 配置 containerd 镜像加速源..."
    multipass exec "${vm}" -- sudo bash -c '
      swapoff -a
      # 备份并重置生成干净的标准配置
      cp -n /etc/containerd/config.toml /etc/containerd/config.toml.bak 2>/dev/null || true
      containerd config default > /etc/containerd/config.toml
      sed -i "s/SystemdCgroup = false/SystemdCgroup = true/g" /etc/containerd/config.toml
      sed -i -E "s#(sandbox_image\s*=\s*)\"[^\"]+\"#\1\"registry.aliyuncs.com/google_containers/pause:3.9\"#g" /etc/containerd/config.toml
      systemctl daemon-reload
      systemctl restart containerd
      systemctl restart kubelet
    '
    echo "  ✅ ${vm} containerd 标准配置与 SystemdCgroup 已修复！"
  else
    echo "  ⚠️ 未找到虚拟机 ${vm}，跳过。"
  fi
done

echo "======================================================================"
echo " 🎉 集群前置配置全部就绪！"
echo " 现在可以重新运行: ./scripts/helm-install.sh"
echo "======================================================================"
