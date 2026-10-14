#!/usr/bin/env bash
# ==============================================================================
# Script: 1-Click Create 3 VMs on 1 Physical Host via Multipass for K8s HA
# Purpose: 在单台物理机上自动创建 3 台 Ubuntu 虚拟机，并自动完成底座初始化
# ==============================================================================
set -euo pipefail

CPUS="${1:-2}"
RAW_MEM="${2:-4G}"
RAW_DISK="${3:-20G}"

# 如果用户只输入了纯数字（如 8 或 40），自动补全单位 G
if [[ "${RAW_MEM}" =~ ^[0-9]+$ ]]; then
    MEMORY="${RAW_MEM}G"
else
    MEMORY="${RAW_MEM}"
fi

if [[ "${RAW_DISK}" =~ ^[0-9]+$ ]]; then
    DISK="${RAW_DISK}G"
else
    DISK="${RAW_DISK}"
fi

# multipass 命令检测：如果以 sudo 运行，优先切到实际登录用户或保持普通用户
MP_CMD="multipass"
if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
    # 如果用户使用 sudo 执行，multipass 命令用真实用户上下文运行，以保留认证凭据
    MP_USER_CMD="sudo -u ${SUDO_USER} multipass"
else
    MP_USER_CMD="multipass"
fi

echo "=================================================================="
echo "🚀 正在单台物理机上准备 3 台虚拟机 (k8s-master-01 ~ 03)..."
echo "   配置参数: 每台 ${CPUS} 核 CPU, ${MEMORY} 内存, ${DISK} 磁盘"
echo "=================================================================="

# 1. 检查并安装 multipass (Ubuntu 原生极速虚拟机引擎)
if ! command -v multipass &>/dev/null; then
    echo "==> 未检测到 multipass，正在通过 snap 自动安装..."
    if ! command -v snap &>/dev/null; then
        sudo apt-get update && sudo apt-get install -y snapd
    fi
    sudo snap install multipass
fi

# 2. 创建 3 台虚拟机
for node in k8s-master-01 k8s-master-02 k8s-master-03; do
    if ${MP_USER_CMD} info "${node}" &>/dev/null; then
        echo "✅ 虚拟机 [${node}] 已存在，跳过创建。"
    else
        echo "==> 正在创建虚拟机 [${node}]..."
        ${MP_USER_CMD} launch 22.04 --name "${node}" --cpus "${CPUS}" --memory "${MEMORY}" --disk "${DISK}"
    fi
done

# 3. 提取 3 台虚拟机的 IP 地址（确保 DHCP 已获取到有效 IPv4 地址）
get_node_ip() {
    local target="$1"
    local ip=""
    # 尝试从 info 获取
    ip=$(${MP_USER_CMD} info "${target}" 2>/dev/null | awk '/IPv4:/ {print $2}')
    # 如果输出是 -- 或空，尝试在虚拟机内直接执行 hostname -I
    if [ -z "${ip}" ] || [ "${ip}" = "--" ]; then
        ip=$(${MP_USER_CMD} exec "${target}" -- hostname -I 2>/dev/null | awk '{print $1}')
    fi
    # 轮询最多 15 秒等待 IP 分配
    local attempts=0
    while { [ -z "${ip}" ] || [ "${ip}" = "--" ]; } && [ ${attempts} -lt 15 ]; do
        sleep 1
        ip=$(${MP_USER_CMD} exec "${target}" -- hostname -I 2>/dev/null | awk '{print $1}')
        attempts=$((attempts + 1))
    done
    echo "${ip}"
}

IP1=$(get_node_ip "k8s-master-01")
IP2=$(get_node_ip "k8s-master-02")
IP3=$(get_node_ip "k8s-master-03")

# 计算同网段建议 VIP (例如以 .100 结尾)
SUBNET_PREFIX=$(echo "${IP1}" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+' | cut -d. -f1-3 || echo "10.0.4")
if [ -n "${SUBNET_PREFIX}" ] && [ "${SUBNET_PREFIX}" != "--" ]; then
    SUGGESTED_VIP="${SUBNET_PREFIX}.100"
else
    SUGGESTED_VIP="10.0.4.100"
fi

echo ""
echo "=================================================================="
echo "🎉 3 台虚拟机已成功就绪！网络拓扑如下："
echo "   k8s-master-01: ${IP1}"
echo "   k8s-master-02: ${IP2}"
echo "   k8s-master-03: ${IP3}"
echo "   建议虚拟浮动 IP (VIP): ${SUGGESTED_VIP}"
echo "=================================================================="

# 4. 自动分发项目脚本并在 3 台虚拟机内部执行 K8s 底座安装
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "==> 正在将安装脚本同步到 3 台虚拟机内部..."
for node in k8s-master-01 k8s-master-02 k8s-master-03; do
    echo "--> 传输脚本至 [${node}]..."
    ${MP_USER_CMD} exec "${node}" -- sudo mkdir -p /root/scripts/k8s-ha-setup
    ${MP_USER_CMD} transfer "${SCRIPT_DIR}/install-k8s-prerequisites.sh" "${node}:/tmp/install-k8s-prerequisites.sh"
    ${MP_USER_CMD} transfer "${SCRIPT_DIR}/setup-haproxy-keepalived.sh" "${node}:/tmp/setup-haproxy-keepalived.sh"
    ${MP_USER_CMD} transfer "${SCRIPT_DIR}/init-masters.sh" "${node}:/tmp/init-masters.sh"
    
    echo "--> 在 [${node}] 内部执行系统优化与 containerd / kubeadm 安装..."
    ${MP_USER_CMD} exec "${node}" -- sudo bash /tmp/install-k8s-prerequisites.sh
done

echo ""
echo "=================================================================="
echo "✅ 所有 3 台虚拟机底座软件 (containerd + kubeadm + kubectl) 安装完毕！"
echo ""
echo "👉 下一步：在各虚拟机内配置 HAProxy + Keepalived 高可用："
echo "   1) 在 master-01 执行:"
echo "      multipass exec k8s-master-01 -- sudo bash /tmp/setup-haproxy-keepalived.sh ${SUGGESTED_VIP} auto ${IP1} ${IP2} ${IP3}"
echo "   2) 在 master-02 执行:"
echo "      multipass exec k8s-master-02 -- sudo bash /tmp/setup-haproxy-keepalived.sh ${SUGGESTED_VIP} auto ${IP1} ${IP2} ${IP3}"
echo "   3) 在 master-03 执行:"
echo "      multipass exec k8s-master-03 -- sudo bash /tmp/setup-haproxy-keepalived.sh ${SUGGESTED_VIP} auto ${IP1} ${IP2} ${IP3}"
echo ""
echo "👉 第 3 步：初始化集群（在 master-01 上执行）:"
echo "   multipass exec k8s-master-01 -- sudo bash /tmp/init-masters.sh ${SUGGESTED_VIP}"
echo "=================================================================="
