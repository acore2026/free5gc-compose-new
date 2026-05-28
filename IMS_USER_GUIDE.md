# IMS通话使用指南

## IMS服务部署状态
- P-CSCF地址：10.88.120.99:5060
- SIP协议：UDP/TCP
- IMS域名：ims.free5gc.org
- 服务状态：运行中

## 手机IMS通话流程

### 1. 手机端配置要求

#### SIM卡参数：
```
IMSI: 001012345678910
Key (K): 12345678901234567890123456789012
OP: 12345678901234561234567890123456
AMF: 8000
```

#### 手机设置：
- 启用VoLTE（Voice over LTE）
- 启用IMS服务
- APN配置包含ims DNN

### 2. 网络注册流程

手机开机后自动执行：

**步骤1：5G网络注册**
- 手机连接到gNB
- 向AMF发送Registration Request
- AMF返回Registration Accept
- 状态：5G注册成功

**步骤2：建立PDU Session**
- 手机请求建立两个PDU Session：
  - **internet**：用于上网（IP: 10.60.0.x）
  - **ims**：用于语音通话（IP: 10.64.0.x）

**步骤3：IMS注册**
- 手机通过ims PDU Session向P-CSCF发送REGISTER
- REGISTER消息格式：
  ```
  REGISTER sip:ims.free5gc.org SIP/2.0
  Via: SIP/2.0/UDP 10.64.0.x:5060
  From: <sip:001012345678910@ims.free5gc.org>
  To: <sip:001012345678910@ims.free5gc.org>
  Contact: <sip:001012345678910@10.64.0.x:5060>
  ```
- P-CSCF返回200 OK
- 状态：IMS注册成功

### 3. 发起语音通话

**步骤1：主叫方发起INVITE**
- 手机发送INVITE请求：
  ```
  INVITE sip:001012345678911@ims.free5gc.org SIP/2.0
  Via: SIP/2.0/UDP 10.64.0.x:5060
  From: <sip:001012345678910@ims.free5gc.org>
  To: <sip:001012345678911@ims.free5gc.org>
  Call-ID: abc123@10.64.0.x
  ```
- IMS服务器路由到被叫方

**步骤2：被叫方接收**
- 被叫手机振铃
- 返回180 Ringing
- 返回200 OK with SDP

**步骤3：建立语音通道**
- 主叫发送ACK确认
- 双方建立RTP语音通道
- 开始通话

**步骤4：结束通话**
- 任一方发送BYE
- 对方返回200 OK
- 释放语音通道

### 4. 当前问题诊断

#### ims PDU Session被释放的原因：

根据日志分析，ims PDU Session建立后约8秒被UE主动释放。

可能原因：
1. **IMS服务未被发现**：UE无法连接到P-CSCF (10.88.120.99:5060)
2. **IMS注册失败**：UE尝试IMS注册但失败，导致释放会话
3. **UE配置问题**：手机未正确配置IMS参数

#### 解决方案：

**方案1：检查网络连通性**
```bash
# 在UE侧ping P-CSCF地址（需要UE具备ping功能）
ping 10.88.120.99

# 检查SIP端口可达性
nc -u -v 10.88.120.99 5060
```

**方案2：验证IMS服务状态**
```bash
# 检查IMS服务是否运行
netstat -tuln | grep 5060

# 检查Kamailio进程
ps aux | grep kamailio

# 查看IMS日志
sudo journalctl -u kamailio -f
```

**方案3：手动触发IMS注册测试**
```bash
# 使用SIP客户端测试（需要安装sipcmd或sipp）
sipcmd -u 001012345678910 -p 10.64.0.x -h 10.88.120.99 -r REGISTER
```

**方案4：检查UE配置**
- 确认UE支持IMS/VoLTE
- 检查UE的ims DNN配置
- 验证P-CSCF地址配置是否正确

### 5. IMS服务管理

#### 启动IMS：
```bash
/home/core/start-ims.sh
```

#### 停止IMS：
```bash
/home/core/stop-ims.sh
```

#### 检查IMS状态：
```bash
systemctl status kamailio
netstat -tuln | grep 5060
```

#### 查看IMS日志：
```bash
sudo journalctl -u kamailio -n 50
sudo tail -f /var/log/syslog | grep kamailio
```

### 6. IMS测试工具

#### SIPp测试（推荐）：
```bash
# 安装SIPp
sudo apt install sipp

# IMS注册测试
sipp -sn uac -i 10.64.0.x -p 5060 10.88.120.99:5060 -m 1

# IMS呼叫测试
sipp -sn uac_cseq -i 10.64.0.x -p 5060 10.88.120.99:5060 -m 1
```

#### Kamailio内置测试：
```bash
# 查看注册用户
kamctl ul show

# 查看活动通话
kamctl dialog show

# 发送测试SIP消息
kamctl fifo sip_trace
```

### 7. 常见问题排查

#### Q1：ims PDU Session建立后立即释放
**原因**：IMS服务不可达或UE未正确配置IMS
**解决**：检查P-CSCF地址配置、UE IMS支持、网络连通性

#### Q2：IMS注册失败
**原因**：SIP消息格式错误或P-CSCF未响应
**解决**：查看Kamailio日志，检查SIP消息格式

#### Q3：无法发起呼叫
**原因**：被叫方未注册IMS或路由失败
**解决**：确认双方都已IMS注册，检查IMS路由配置

### 8. IMS服务监控

#### 实时监控：
```bash
# 监控SIP消息
sudo tcpdump -i eth0 port 5060 -w sip_trace.pcap

# 分析SIP流量
sudo wireshark sip_trace.pcap
```

#### 注册状态：
```bash
# 查看已注册UE
kamctl ul show

# 查看特定UE
kamctl ul show 001012345678910
```

### 9. 下一步建议

为了使手机能够通过IMS打电话，建议：

1. **验证UE IMS支持**：确认手机支持VoLTE/IMS功能
2. **检查UE配置**：确保UE配置了ims DNN和P-CSCF地址
3. **测试IMS连通性**：在UE侧测试能否连接10.88.120.99:5060
4. **捕获SIP消息**：使用tcpdump捕获IMS注册和呼叫过程
5. **分析日志**：查看Kamailio日志确认IMS注册和呼叫流程

---

**IMS服务已部署完成，但需要UE正确配置和测试验证。**