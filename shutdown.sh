#!/bin/bash

Server_Dir=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
Conf_Dir="$Server_Dir/conf"

source "$Server_Dir/scripts/stop_mihomo.sh"

## 关闭本目录下所有 mihomo 进程（按 conf 路径匹配，不影响其他安装）
stop_project_mihomo "$Server_Dir"
remaining=$(pgrep -f " -d ${Conf_Dir}( |$)" 2>/dev/null | wc -l)
if [ "$remaining" -gt 0 ]; then
	echo "警告：仍有 ${remaining} 个 mihomo 进程未退出，请检查：pgrep -fa \" -d ${Conf_Dir}\"" >&2
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
