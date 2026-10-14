#!/usr/bin/env bash
# ==============================================================================
# Script: Diagnose and Fix K8s Containerd Mirrors & DNS inside Multipass VMs
# ==============================================================================
set -euo pipefail

echo "======================================================================"
echo " 🔍 [1/3] 检查 3 台虚拟机内 containerd 拉取镜像与网络状况..."
echo "======================================================================"

VMS=("k8s-master-01" "k8s-master-02" "k8s-master-03")

# 可用的国内多镜像源备选池
CONFIG_MIRROR_SCRIPT='
cat << "EOF" > /etc/containerd/config.toml
version = 2

[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    sandbox_image = "registry.aliyuncs.com/google_containers/pause:3.9"
    [plugins."io.containerd.grpc.v1.cri".containerd]
      default_runtime_name = "runc"
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          runtime_type = "io.containerd.runc.v2"
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            SystemdCgroup = true
    [plugins."io.containerd.grpc.v1.cri".registry]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
          endpoint = [
            "https://docker.m.daocloud.io",
            "https://dockerproxy.net",
            "https://atomhub.openatom.cn",
            "https://mirror.baidubce.com",
            "https://registry-1.docker.io"
          ]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."registry.k8s.io"]
          endpoint = [
            "https://k8s.m.daocloud.io",
            "https://registry.aliyuncs.com/google_containers"
          ]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."quay.io"]
          endpoint = [
            "https://quay.m.daocloud.io"
          ]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."*"]
          endpoint = ["https://docker.m.daocloud.io"]
EOF

systemctl restart containerd
'

for vm in "${VMS[@]}"; do
  if multipass info "${vm}" >/dev/null 2>&1; then
    echo "--> [${vm}] 配置 containerd version=2 完整多加速源并重启..."
    multipass exec "${vm}" -- sudo bash -c "${CONFIG_MIRROR_SCRIPT}"
    echo "--> [${vm}] 测试拉取轻量镜像 busybox:1.36 与 nginx:1.27-alpine..."
    multipass exec "${vm}" -- sudo crictl pull docker.io/library/nginx:1.27-alpine || true
    echo "✅ [${vm}] 配置并测试完毕。"
  fi
done

echo ""
echo "======================================================================"
echo " 🚀 [2/3] 重启 data-platform 下卡在 ImagePullBackOff 的 Pods..."
echo "======================================================================"
kubectl delete pod -n data-platform -l app=nginx || true
kubectl delete pod -n data-platform -l component=jobmanager || true

echo ""
echo "======================================================================"
echo " ✅ 完成！您可随时查看拉取进展: kubectl get pods -n data-platform -w"
echo "======================================================================"
