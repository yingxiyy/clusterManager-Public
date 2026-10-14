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

# 1. 验证 kubectl 连接
if ! kubectl cluster-info >/dev/null 2>&1 && ! kubectl get nodes >/dev/null 2>&1; then
  echo "❌ 无法通过 kubectl 连接集群，请先确认 ~/.kube/config 已正确配置。"
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
    multipass exec "${vm}" -- sudo bash -c 'cat <<EOF > /tmp/update-containerd-mirrors.py
import re

config_path = "/etc/containerd/config.toml"
try:
    with open(config_path, "r") as f:
        content = f.read()
except Exception:
    content = ""

# Check if mirrors are already configured
if "docker.m.daocloud.io" not in content:
    mirror_config = """
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
          endpoint = ["https://docker.m.daocloud.io", "https://dockerproxy.net", "https://registry-1.docker.io"]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."registry.k8s.io"]
          endpoint = ["https://k8s.m.daocloud.io", "https://registry.aliyuncs.com/google_containers"]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."quay.io"]
          endpoint = ["https://quay.m.daocloud.io"]
"""
    if "[plugins.\"io.containerd.grpc.v1.cri\".registry]" in content:
        content = content.replace("[plugins.\"io.containerd.grpc.v1.cri\".registry]", "[plugins.\"io.containerd.grpc.v1.cri\".registry]" + mirror_config)
    else:
        content += "\n" + mirror_config
    with open(config_path, "w") as f:
        f.write(content)
EOF
python3 /tmp/update-containerd-mirrors.py
systemctl restart containerd
'
    echo "  ✅ ${vm} containerd 镜像加速配置完成！"
  else
    echo "  ⚠️ 未找到虚拟机 ${vm}，跳过。"
  fi
done

echo "======================================================================"
echo " 🎉 集群前置配置全部就绪！"
echo " 现在可以重新运行: ./scripts/helm-install.sh"
echo "======================================================================"
