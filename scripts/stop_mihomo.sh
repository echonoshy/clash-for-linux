#!/bin/bash

# 停止当前 clash-for-linux 安装目录下的所有 mihomo 进程（不影响其他路径的安装）
stop_project_mihomo() {
	local server_dir="$1"
	local conf_dir="${server_dir}/conf"
	local pid_file="${server_dir}/temp/clash.pid"
	local pid
	local -a pids=()

	if [ -z "$server_dir" ] || [ ! -d "$conf_dir" ]; then
		return 1
	fi

	if [ -f "$pid_file" ]; then
		pid=$(cat "$pid_file" 2>/dev/null)
		[ -n "$pid" ] && pids+=("$pid")
	fi

	while IFS= read -r pid; do
		[ -n "$pid" ] && pids+=("$pid")
	done < <(pgrep -f " -d ${conf_dir}( |$)" 2>/dev/null || true)

	if [ ${#pids[@]} -eq 0 ]; then
		rm -f "$pid_file" 2>/dev/null || true
		return 0
	fi

	# 去重
	local -A seen=()
	local -a unique_pids=()
	for pid in "${pids[@]}"; do
		if [ -z "${seen[$pid]}" ]; then
			seen[$pid]=1
			unique_pids+=("$pid")
		fi
	done

	for pid in "${unique_pids[@]}"; do
		kill "$pid" 2>/dev/null || true
	done
	sleep 1
	for pid in "${unique_pids[@]}"; do
		if kill -0 "$pid" 2>/dev/null; then
			kill -9 "$pid" 2>/dev/null || true
		fi
	done

	rm -f "$pid_file" 2>/dev/null || true
}
