# Free5GC 离线部署包

## 目录结构
```
start5GC/
├── images/                    # Docker镜像文件
│   ├── free5gc-images.tar     # Free5GC组件镜像
│   └── mongo-image.tar        # MongoDB镜像
├── config/                    # 配置文件
├── cert/                      # 证书文件
├── free5gc-config/            # UPF附加配置
└── docker-compose.yaml        # Docker Compose配置

start5GC.sh                    # 一键启动脚本
stop5GC.sh                     # 停止脚本
```

## 使用方法

### 启动核心网
```bash
./start5GC.sh
```

### 停止核心网
```bash
./stop5GC.sh
```

## 服务端口
- WebUI: http://localhost:5000
- AMF: 10.88.120.100:38412/sctp
- UPF: 2152/udp, 8805/udp, 9082/tcp

## 注意事项
1. 确保已安装 Docker 和 Docker Compose
2. 确保端口未被占用
3. 首次启动需要加载镜像，需要等待一段时间