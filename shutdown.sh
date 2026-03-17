#!/bin/bash

Server_Dir=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
Temp_Dir="$Server_Dir/temp"
PID_FILE="$Temp_Dir/clash.pid"

## 关闭 mihomo 进程
if [ -f "$PID_FILE" ]; then
	PID=$(cat "$PID_FILE" 2>/dev/null)
	if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
		kill "$PID" 2>/dev/null || true
		sleep 1
		if kill -0 "$PID" 2>/dev/null; then
			kill -9 "$PID" 2>/dev/null || true
		fi
	fi
	rm -f "$PID_FILE" 2>/dev/null || true
else
	echo "未找到 PID 文件，若需要可手动检查进程：pgrep -fa clash-linux" >&2
fi

## 清空代理环境函数文件
ENV_FILE="$HOME/.clash_proxy_env.sh"
[ -f "$ENV_FILE" ] && : > "$ENV_FILE"

## 从 ~/.bashrc 中移除自动注入的行
BASHRC="$HOME/.bashrc"
if [ -f "$BASHRC" ]; then
	sed -i '/^# Load Clash proxy helpers/d' "$BASHRC"
	sed -i '/\.clash_proxy_env\.sh/d' "$BASHRC"
	awk 'BEGIN{b=0}{if($0~/^$/){if(b==0){print;b=1}}else{print;b=0}}' "$BASHRC" > "$BASHRC.tmp" && mv "$BASHRC.tmp" "$BASHRC"
fi

echo -e "\n服务关闭成功，请执行以下命令关闭系统代理：proxy_off\n"
