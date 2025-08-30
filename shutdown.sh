#!/bin/bash

Server_Dir=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
Temp_Dir="$Server_Dir/temp"
PID_FILE="$Temp_Dir/clash.pid"

# 关闭clash服务（仅限当前实例，避免误杀其他用户的进程）
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
	echo "未找到 PID 文件，若需要可手动检查进程：pgrep -fa 'clash-linux-(amd64|arm64|armv7)'" >&2
fi

# 清除环境变量定义（仅清理当前用户的环境文件）
ENV_FILE="$HOME/.clash_proxy_env.sh"

if [ -f "$ENV_FILE" ]; then
	# 清空但保留文件，避免 source 失败
	: > "$ENV_FILE"
fi

# 从 ~/.bashrc 中移除自动添加的 source 行与标记注释（仅当前用户）
BASHRC="$HOME/.bashrc"
if [ -f "$BASHRC" ]; then
	# 删除标记注释行
	sed -i '/^# Load Clash proxy helpers (added by clash-for-linux\/start\.sh)$/d' "$BASHRC"
	# 删除引用 .clash_proxy_env.sh 的行
	sed -i '/\.clash_proxy_env\.sh/d' "$BASHRC"
	# 合并可能产生的多余空行（最多保留一个空行）
	awk 'BEGIN{blank=0} { if ($0 ~ /^$/) { if (blank==0) { print; blank=1 } } else { print; blank=0 } }' "$BASHRC" > "$BASHRC.tmp" && mv "$BASHRC.tmp" "$BASHRC"
fi

echo -e "\n服务关闭成功，请执行以下命令关闭系统代理：proxy_off\n"
