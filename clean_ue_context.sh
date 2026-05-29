#!/bin/bash

# 清理用户注册上下文脚本
# 保留：用户签约数据、NF实例注册信息、测量相关数据（计费、流规则、QoS流）、身份数据、策略数据、URI列表
# 清理：AMF上下文、认证状态

# 支持参数：
#   --imsi <imsi>  : 清理指定IMSI的上下文
#   --all          : 清理所有UE的上下文（默认）

set -e

echo "=========================================="
echo "清理用户注册上下文"
echo "=========================================="
echo ""

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 参数解析
TARGET_IMSI=""
MODE="interactive"

while [[ $# -gt 0 ]]; do
    case $1 in
        --imsi|-i)
            TARGET_IMSI="$2"
            MODE="specific"
            shift 2
            ;;
        --all|-a)
            MODE="all"
            shift
            ;;
        --help|-h)
            echo "用法:"
            echo "  $0 [--imsi <imsi>] [--all]"
            echo ""
            echo "选项:"
            echo "  --imsi, -i <imsi>  清理指定IMSI的上下文（例如：imsi-001012345678909）"
            echo "  --all, -a          清理所有UE的上下文"
            echo "  --help, -h         显示帮助信息"
            echo ""
            exit 0
            ;;
        *)
            echo -e "${RED}未知参数: $1${NC}"
            exit 1
            ;;
    esac
done

# 如果是交互式模式，让用户选择
if [ "$MODE" == "interactive" ]; then
    echo -e "${BLUE}请选择清理模式：${NC}"
    echo "  1) 清理指定UE的上下文"
    echo "  2) 清理所有UE的上下文"
    echo "  3) 显示当前注册的UE列表"
    echo "  4) 退出"
    echo ""
    read -p "请选择 [1-4]: " choice
    
    case $choice in
        1)
            read -p "请输入IMSI（例如：imsi-001012345678909）: " TARGET_IMSI
            if [ -z "$TARGET_IMSI" ]; then
                echo -e "${RED}IMSI不能为空${NC}"
                exit 1
            fi
            MODE="specific"
            ;;
        2)
            MODE="all"
            ;;
        3)
            echo -e "${YELLOW}当前注册的UE：${NC}"
            curl -s http://localhost:8000/namf-oam/v1/registered-ue-context 2>/dev/null || echo "无法连接到AMF"
            echo ""
            exit 0
            ;;
        4)
            echo -e "${GREEN}已退出${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            exit 1
            ;;
    esac
fi

# 构建MongoDB查询条件
if [ "$MODE" == "specific" ]; then
    MONGO_FILTER="{ueId: '$TARGET_IMSI'}"
    MONGO_FILTER_POLICY="{ueId: '$TARGET_IMSI'}"
    echo -e "${BLUE}目标IMSI: $TARGET_IMSI${NC}"
    echo ""
else
    MONGO_FILTER="{}"
    MONGO_FILTER_POLICY="{}"
    echo -e "${BLUE}清理模式: 所有UE${NC}"
    echo ""
fi

# 显示清理前的统计信息
echo -e "${YELLOW}清理前的数据统计：${NC}"
echo "----------------------------------------"
docker exec mongodb mongo --quiet --eval "
db = db.getSiblingDB('free5gc');

var filter = $MONGO_FILTER;
var filterPolicy = $MONGO_FILTER_POLICY;

print('【将保留的数据】');
print('  认证订阅数据: ' + db.subscriptionData.authenticationData.authenticationSubscription.count());
print('  Web认证订阅: ' + db.subscriptionData.authenticationData.webAuthenticationSubscription.count());
print('  AM配置数据: ' + db.subscriptionData.provisionedData.amData.count());
print('  SM配置数据: ' + db.subscriptionData.provisionedData.smData.count());
print('  SMF选择订阅: ' + db.subscriptionData.provisionedData.smfSelectionSubscriptionData.count());
print('  NF实例信息: ' + db.NfProfile.count());
print('  租户数据: ' + db.tenantData.count());
print('  用户数据: ' + db.userData.count());
print('');
print('  === 测量相关数据（保留）===');
print('  计费数据: ' + db['policyData.ues.chargingData'].count(filterPolicy));
print('  流规则: ' + db['policyData.ues.flowRule'].count(filterPolicy));
print('  QoS流: ' + db['policyData.ues.qosFlow'].count(filterPolicy));
print('');
print('【将保留的运行时数据】');
print('  身份数据: ' + db.subscriptionData.identityData.count(filter));
print('  策略AM数据: ' + db['policyData.ues.amData'].count(filterPolicy));
print('  SM策略数据: ' + db['policyData.ues.smData'].count(filterPolicy));
print('  URI列表: ' + db.urilist.count());
print('');
print('【将清理的数据】');
print('  AMF上下文: ' + db.subscriptionData.contextData.amf3gppAccess.count(filter));
print('  认证状态: ' + db.subscriptionData.authenticationData.authenticationStatus.count(filter));
"

echo ""
echo "----------------------------------------"
if [ "$MODE" == "specific" ]; then
    read -p "确认清理UE [$TARGET_IMSI] 的上下文？(yes/no): " confirm
else
    read -p "确认清理所有UE的上下文？(yes/no): " confirm
fi

if [ "$confirm" != "yes" ]; then
    echo -e "${RED}已取消操作${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}开始清理...${NC}"

# 尝试通过AMF API清理UE上下文（内存）
if [ "$MODE" == "specific" ]; then
    echo -e "${BLUE}尝试清理AMF内存中的上下文...${NC}"
    # 尝试触发隐式去注册（通过AMF的内部机制）
    # 注意：这可能不会成功，因为AMF可能没有提供直接的API
    # 但我们可以记录尝试
    echo "  (AMF内存上下文需要通过重启AMF或等待隐式去注册超时清理)"
fi

# 尝试通过SMF API清理PDU会话（内存）
if [ "$MODE" == "specific" ]; then
    echo -e "${BLUE}尝试清理SMF内存中的PDU会话...${NC}"
    # 尝试查询并通知SMF释放会话
    # SMF的PFCP会话需要通过正常流程释放
    echo "  (SMF内存会话需要通过正常去注册流程或PFCP会话超时清理)"
fi

# 清理MongoDB中的用户上下文数据
docker exec mongodb mongo --quiet --eval "
db = db.getSiblingDB('free5gc');

var filter = $MONGO_FILTER;
var filterPolicy = $MONGO_FILTER_POLICY;
var results = {};

// 清理AMF上下文
results.amfContext = db.subscriptionData.contextData.amf3gppAccess.deleteMany(filter);
print('✓ AMF上下文: 删除 ' + results.amfContext.deletedCount + ' 条记录');

// 清理认证状态
results.authStatus = db.subscriptionData.authenticationData.authenticationStatus.deleteMany(filter);
print('✓ 认证状态: 删除 ' + results.authStatus.deletedCount + ' 条记录');

// 保留身份数据
print('○ 身份数据: 已保留');

// 保留策略数据
print('○ 策略AM数据: 已保留');

// 保留测量相关数据（计费数据、流规则、QoS流）
print('○ 计费数据: 已保留（测量数据）');
print('○ 流规则: 已保留（测量数据）');
print('○ QoS流: 已保留（测量数据）');

// 保留SM策略数据
print('○ SM策略数据: 已保留');

// 保留URI列表
print('○ URI列表: 已保留');
"

echo ""
echo -e "${GREEN}MongoDB数据清理完成！${NC}"
echo ""

# 显示清理后的统计信息
echo "----------------------------------------"
echo -e "${GREEN}清理后的数据统计：${NC}"
docker exec mongodb mongo --quiet --eval "
db = db.getSiblingDB('free5gc');

var filter = $MONGO_FILTER;
var filterPolicy = $MONGO_FILTER_POLICY;

print('【保留的数据（签约数据）】');
print('  认证订阅数据: ' + db.subscriptionData.authenticationData.authenticationSubscription.count());
print('  Web认证订阅: ' + db.subscriptionData.authenticationData.webAuthenticationSubscription.count());
print('  AM配置数据: ' + db.subscriptionData.provisionedData.amData.count());
print('  SM配置数据: ' + db.subscriptionData.provisionedData.smData.count());
print('  SMF选择订阅: ' + db.subscriptionData.provisionedData.smfSelectionSubscriptionData.count());
print('  NF实例信息: ' + db.NfProfile.count());
print('  租户数据: ' + db.tenantData.count());
print('  用户数据: ' + db.userData.count());
print('');
print('  === 测量相关数据（保留）===');
print('  计费数据: ' + db['policyData.ues.chargingData'].count(filterPolicy));
print('  流规则: ' + db['policyData.ues.flowRule'].count(filterPolicy));
print('  QoS流: ' + db['policyData.ues.qosFlow'].count(filterPolicy));
print('');
print('  === 其他运行时数据（保留）===');
print('  身份数据: ' + db.subscriptionData.identityData.count(filter));
print('  策略AM数据: ' + db['policyData.ues.amData'].count(filterPolicy));
print('  SM策略数据: ' + db['policyData.ues.smData'].count(filterPolicy));
print('  URI列表: ' + db.urilist.count());
print('');
print('【已清空的上下文】');
print('  AMF上下文: ' + db.subscriptionData.contextData.amf3gppAccess.count(filter));
print('  认证状态: ' + db.subscriptionData.authenticationData.authenticationStatus.count(filter));
"

echo ""
echo -e "${YELLOW}注意事项：${NC}"
echo "  • MongoDB数据已清理，但NF内存中的上下文可能仍然存在"
echo "  • AMF和SMF需要通过正常去注册流程或超时机制清理内存"
echo "  • UPF的PFCP会话可能需要手动清理或等待超时"
echo "  • 签约数据已保留，UE可以重新注册"

# 重启所有网元以清理内存上下文
echo ""
echo -e "${YELLOW}重启所有网元...${NC}"

docker-compose down
docker-compose up -d
echo -e "${GREEN}所有网元已重启完成！${NC}"

echo ""
echo "=========================================="
echo -e "${GREEN}清理操作完成！${NC}"
