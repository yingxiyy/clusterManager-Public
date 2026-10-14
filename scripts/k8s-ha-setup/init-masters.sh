#!/usr/bin/env bash
# ==============================================================================
# Script: Kubeadm 3-Master HA Initialization & Untaint for Worker Workloads
# ==============================================================================
set -euo pipefail

VIP_ENDPOINT="${1:-192.168.1.100}"
# If user provided just IP without port, append HAProxy port :16443
if [[ "${VIP_ENDPOINT}" != *":"* ]]; then
  CONTROL_PLANE_ENDPOINT="${VIP_ENDPOINT}:16443"
else
  CONTROL_PLANE_ENDPOINT="${VIP_ENDPOINT}"
fi

IMAGE_REPO="${2:-registry.aliyuncs.com/google_containers}"
INSTALL_DIR="${3:-/opt/kubernetes}"

mkdir -p "${INSTALL_DIR}"
cd "${INSTALL_DIR}"

echo "Step 1: Initializing Master 1 via VIP ${CONTROL_PLANE_ENDPOINT} (Image Repo: ${IMAGE_REPO})..."
kubeadm init \
  --control-plane-endpoint "${CONTROL_PLANE_ENDPOINT}" \
  --image-repository "${IMAGE_REPO}" \
  --upload-certs \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=$(hostname -I | awk '{print $1}')

mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

echo "Step 2: Installing CNI (Flannel/Calico)..."
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

echo "Step 3: Untaint Master nodes so worker pods (Kafka, Mongo, Flink) can run on them..."
kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true
kubectl taint nodes --all node-role.kubernetes.io/master- || true

echo "Cluster initialized! To join the other 2 masters:"
echo "kubeadm join ${CONTROL_PLANE_ENDPOINT} --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH> --control-plane --certificate-key <CERT_KEY>"
echo ""
echo "To join extension worker nodes:"
echo "kubeadm join ${CONTROL_PLANE_ENDPOINT} --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH>"
