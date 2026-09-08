echo [步骤1] 配置网络IP地址
ip addr add 10.88.120.100/24 dev eth1 2>/dev/null || echo IP已存在
# [10.88.120.99 removed — caused SCTP multi-homing ABORT loop on NGAP] ip addr add 10.88.120.99/24 dev eth1 2>/dev/null || echo IP已存在
ip link set eth1 up
ip addr show eth1 | grep inet
echo

echo [步骤2] 加载gtp5g内核模块
if lsmod | grep -q gtp5g; then
  echo 移除旧gtp5g模块
  rmmod gtp5g 2>/dev/null
fi

if [ -f /home/core/gtp5g/gtp5g.ko ]; then
  echo 加载预编译gtp5g模块
  if insmod /home/core/gtp5g/gtp5g.ko; then
    lsmod | grep gtp5g
    echo gtp5g模块加载成功
  else
    echo 错误: gtp5g模块加载失败
    echo 请检查内核版本是否匹配: uname -r
    echo 查看详细错误: dmesg \| tail -20
    exit 1
  fi
else
  echo 错误: 未找到gtp5g.ko文件
  exit 1
fi
echo

sudo ip addr add 10.100.200.99/24 dev br-free5gc
echo [步骤3] UPF---IMS网络打通




