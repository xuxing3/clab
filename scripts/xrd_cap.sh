#!/bin/bash
# 用法:
#   ./xrd_pcap.sh clab-evpn-lab-PE4 0/0/0/0 20
#   ./xrd_pcap.sh clab-evpn-lab-PE4 Gi0-0-0-0
# 说明:
#   第2个参数既可用 0/0/0/0，也可用 Gi0-0-0-0；都会被规范化为 Gi0-0-0-0

set -euo pipefail

NODE="${1:-}"     # 容器名，如 clab-evpn-lab-PE4
RAW_IF="${2:-}"   # XR 接口名，支持 0/0/0/0 或 Gi0-0-0-0
DUR="${3:-0}"     # 抓包秒数；0 表示手动 Ctrl+C 结束

if [[ -z "$NODE" || -z "$RAW_IF" ]]; then
  echo "Usage: $0 <container-name> <XR-interface(0/0/0/0|Gi0-0-0-0)> [seconds]"
  exit 1
fi

# 将 0/0/0/0 → Gi0-0-0-0；若已是 Gi0-0-0-0 或 gi0-0-0-0 则保持 Gi 大写
normalize_iface() {
  local in="$1"
  # 1) 如果是形如 0/0/0/0，替换为 Gi0-0-0-0
  if [[ "$in" =~ ^[0-9]+/[0-9]+/[0-9]+/[0-9]+$ ]]; then
    echo "Gi${in//\//-}"
    return
  fi
  # 2) 如果是 Gi0-0-0-0 / gi0-0-0-0，统一为 Gi 前缀
  if [[ "$in" =~ ^[Gg][Ii][0-9-]+$ ]]; then
    echo "Gi${in:2}"
    return
  fi
  # 3) 其他情况原样返回（以防自定义接口名）
  echo "$in"
}

XRIF="$(normalize_iface "$RAW_IF")"

# 找容器 PID
PID="$(docker inspect -f '{{.State.Pid}}' "$NODE")"

# 准备 netns 链接（同名覆盖）
sudo mkdir -p /var/run/netns
sudo ln -sf "/proc/${PID}/ns/net" "/var/run/netns/${NODE}"

# 退出时清理 netns 链接（正常退出 / Ctrl+C / timeout 触发都会执行）
cleanup() {
  # 使用 || true 防止已被手动删除时报错
  sudo rm -f "/var/run/netns/${NODE}" || true
}
trap cleanup EXIT INT TERM

# 校验接口是否存在
if !  sudo ip netns exec "$NODE" ip link show "$XRIF" &>/dev/null; then
  echo "ERROR: interface '$XRIF' not found in netns '$NODE'"
  echo "Hint: run 'ip netns exec $NODE ip link' to list interfaces."
  exit 2
fi

PCAP="/tmp/${NODE}_${XRIF}_$(date +%H%M%S).pcap"
echo "=> Capturing ${NODE}:${XRIF} into ${PCAP}"

if [[ "$DUR" -gt 0 ]]; then
  # timeout 结束后也会触发 trap，自动清理 netns 链接
  sudo timeout "$DUR" ip netns exec "$NODE" tcpdump -i "$XRIF" -s 0 -w "$PCAP"
else
  # Ctrl+C 中断会触发 trap，自动清理 netns 链接
  sudo ip netns exec "$NODE" tcpdump -i "$XRIF" -s 0 -w "$PCAP"
fi

echo "=> Done. PCAP at ${PCAP}"