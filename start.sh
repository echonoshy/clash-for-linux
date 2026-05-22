#!/bin/bash

#################### 脚本初始化 ####################

Server_Dir=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

[ -f "$Server_Dir/.env" ] && source "$Server_Dir/.env"

chmod +x $Server_Dir/bin/*
chmod +x $Server_Dir/scripts/*

#################### 变量设置 ####################

Conf_Dir="$Server_Dir/conf"
Temp_Dir="$Server_Dir/temp"
Log_Dir="$Server_Dir/logs"

mkdir -p "$Conf_Dir" "$Temp_Dir" "$Log_Dir"

URL=${CLASH_URL:?Error: CLASH_URL variable is not set or empty}
Secret=${CLASH_SECRET:-$(openssl rand -hex 32)}

#################### 函数定义 ####################

success() {
	echo -en "\\033[60G[\\033[1;32m  OK  \\033[0;39m]\r"
	return 0
}

failure() {
	local rc=$?
	echo -en "\\033[60G[\\033[1;31mFAILED\\033[0;39m]\r"
	return $rc
}

action() {
	local STRING rc
	STRING=$1
	echo -n "$STRING "
	shift
	"$@" && success $"$STRING" || failure $"$STRING"
	rc=$?
	echo
	return $rc
}

if_success() {
	local ReturnStatus=$3
	if [ $ReturnStatus -eq 0 ]; then
		action "$1" /bin/true
	else
		action "$2" /bin/false
		exit 1
	fi
}

#################### 任务执行 ####################

## 获取 CPU 架构
source $Server_Dir/scripts/get_cpu_arch.sh

if [[ -z "$CpuArch" ]]; then
	echo "Failed to obtain CPU architecture"
	exit 1
fi

## 清除可能残留的代理环境变量，避免干扰订阅下载
unset http_proxy https_proxy no_proxy HTTP_PROXY HTTPS_PROXY NO_PROXY

## 订阅请求使用的 UA（部分机场会按 UA 白名单过滤，clash.meta 兼容性最好）
SUB_UA="clash.meta"

## 检测订阅地址
echo -e '\n正在检测订阅地址...'
curl -o /dev/null -L -k -sS --retry 5 -m 10 --connect-timeout 10 -A "$SUB_UA" -w "%{http_code}" $URL | grep -E '^[23][0-9]{2}$' &>/dev/null
if_success "订阅地址可访问！" "订阅地址不可访问！" $?

## 下载订阅配置（使用 clash-meta UA 获取 mihomo 兼容的完整配置）
echo -e '\n正在下载配置文件...'
curl -L -k -sS --retry 5 -m 30 -A "$SUB_UA" -o $Temp_Dir/clash.yaml $URL
ReturnStatus=$?
if [ $ReturnStatus -ne 0 ]; then
	for i in {1..10}; do
		wget -q --no-check-certificate -U "$SUB_UA" -O $Temp_Dir/clash.yaml $URL
		ReturnStatus=$?
		[ $ReturnStatus -eq 0 ] && break
	done
fi
if_success "配置文件下载成功！" "配置文件下载失败，退出启动！" $ReturnStatus

## 组装最终配置：模板头部 + 订阅中的代理/规则
sed -n '/^proxies:/,$p' $Temp_Dir/clash.yaml > $Temp_Dir/proxy.txt
cat $Temp_Dir/templete_config.yaml > $Temp_Dir/config.yaml
cat $Temp_Dir/proxy.txt >> $Temp_Dir/config.yaml
\cp $Temp_Dir/config.yaml $Conf_Dir/

## 配置 Dashboard 路径和 Secret
Dashboard_Dir="$Server_Dir/dashboard/public"
sed -ri "s@^# external-ui:.*@external-ui: ${Dashboard_Dir}@g" $Conf_Dir/config.yaml
sed -r -i '/^secret: /s@(secret: ).*@\1'${Secret}'@g' $Conf_Dir/config.yaml

## 选择并启动 mihomo
echo -e '\n正在启动 mihomo 服务...'
if [[ $CpuArch =~ "x86_64" || $CpuArch =~ "amd64" ]]; then
	MIHOMO_BIN="$Server_Dir/bin/clash-linux-amd64"
elif [[ $CpuArch =~ "aarch64" || $CpuArch =~ "arm64" ]]; then
	MIHOMO_BIN="$Server_Dir/bin/clash-linux-arm64"
elif [[ $CpuArch =~ "armv7" ]]; then
	MIHOMO_BIN="$Server_Dir/bin/clash-linux-armv7"
else
	echo -e "\033[31m\n[ERROR] Unsupported CPU Architecture: $CpuArch\033[0m"
	exit 1
fi

SAFE_PATHS="$Server_Dir" nohup "$MIHOMO_BIN" -d "$Conf_Dir" &> "$Log_Dir/clash.log" &
ReturnStatus=$?
MIHOMO_PID=$!
if [ $ReturnStatus -eq 0 ] && kill -0 "$MIHOMO_PID" 2>/dev/null; then
	echo "$MIHOMO_PID" > "$Temp_Dir/clash.pid"
fi
if_success "服务启动成功！" "服务启动失败！" $ReturnStatus

## 输出访问信息
echo ''
echo -e "Clash Dashboard 访问地址: http://<ip>:9091/ui"
echo -e "Secret: ${Secret}"
echo ''

## 写入 proxy_on / proxy_off 快捷函数
ENV_FILE="$HOME/.clash_proxy_env.sh"

cat>"$ENV_FILE"<<'EOF'
function proxy_on() {
	export http_proxy=http://127.0.0.1:7893
	export https_proxy=http://127.0.0.1:7893
	export no_proxy=127.0.0.1,localhost
	export HTTP_PROXY=http://127.0.0.1:7893
	export HTTPS_PROXY=http://127.0.0.1:7893
	export NO_PROXY=127.0.0.1,localhost
	echo -e "\033[32m[√] 已开启代理\033[0m"
}

function proxy_off(){
	unset http_proxy https_proxy no_proxy HTTP_PROXY HTTPS_PROXY NO_PROXY
	echo -e "\033[31m[×] 已关闭代理\033[0m"
}
EOF

## 自动注入 ~/.bashrc（仅首次）
BASHRC="$HOME/.bashrc"
[ -f "$BASHRC" ] || touch "$BASHRC"
if ! grep -Fq ".clash_proxy_env.sh" "$BASHRC" 2>/dev/null; then
	{
		echo ""
		echo "# Load Clash proxy helpers (added by clash-for-linux/start.sh)"
		echo "[ -f \"$HOME/.clash_proxy_env.sh\" ] && source \"$HOME/.clash_proxy_env.sh\""
	} >> "$BASHRC"
	echo -e "已自动写入 ~/.bashrc，新开一个终端即可直接使用 proxy_on/proxy_off。"
	echo -e "当前会话如需立即生效，可执行: source ${ENV_FILE}\n"
else
	echo -e "请执行以下命令加载环境变量: source ${ENV_FILE}\n"
fi
echo -e "请执行以下命令开启系统代理: proxy_on\n"
echo -e "若要临时关闭系统代理，请执行: proxy_off\n"
