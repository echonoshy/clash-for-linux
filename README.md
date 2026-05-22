# clash-for-linux

基于 [mihomo](https://github.com/MetaCubeX/mihomo)（原 Clash.Meta）内核，通过脚本在 Linux 服务器上快速部署代理服务。无需 root 权限，适用于加速 GitHub 下载、访问国外资源等场景。

## 特性

- 使用 mihomo 内核，支持 Trojan/WebSocket/VMess/VLESS/SS 等主流协议
- 无需 root，仅修改当前用户环境
- 一键启动/关闭，自动注入 `proxy_on` / `proxy_off` 快捷命令
- 内置 [YACD](https://github.com/haishanh/yacd) Dashboard，浏览器可视化管理
- 支持 x86_64 / aarch64 / armv7 架构

## 适用环境

- RHEL 系列（CentOS、Fedora 等）
- Debian 系列（Ubuntu、Debian、Linux Mint 等）
- 其他支持 bash 的 Linux 发行版

## 快速开始

### 1. 克隆项目

```bash
git clone https://github.com/wanhebin/clash-for-linux.git
cd clash-for-linux
```

### 2. 配置订阅地址

编辑 `.env` 文件，填入你的订阅链接：

```bash
vim .env
```

```bash
# 必填：你的代理订阅地址
export CLASH_URL='https://your-subscription-url'
# 可选：自定义 Dashboard Secret，留空自动生成
export CLASH_SECRET=''
```

### 3. 启动服务

```bash
bash start.sh
```

启动成功后会输出 Dashboard 地址和 Secret。首次运行会自动将 `proxy_on`/`proxy_off` 注入 `~/.bashrc`。

### 4. 开启代理

```bash
# 首次在当前终端需要手动 source
source ~/.clash_proxy_env.sh
# 开启代理
proxy_on
```

验证代理是否生效：

```bash
curl ipinfo.io
```

如果返回的 IP 不是你本机的，说明代理已生效。

### 5. 关闭代理

临时关闭（仅当前终端）：

```bash
proxy_off
```

完全停止服务：

```bash
bash shutdown.sh
proxy_off
```

## Dashboard

启动后可通过浏览器访问 Clash Dashboard 管理节点和规则：

- 地址：`http://<服务器IP>:9091/ui`
- 在 `API Base URL` 输入 `http://<服务器IP>:9091`
- 在 `Secret` 输入启动时输出的密钥

> 注意：默认 Dashboard API 仅监听 `127.0.0.1`，如需远程访问请修改 `temp/templete_config.yaml` 中的 `external-controller` 为 `0.0.0.0:9091`。

## 项目结构

```
clash-for-linux/
├── .env                          # 订阅地址和 Secret 配置
├── start.sh                      # 启动脚本
├── shutdown.sh                   # 停止脚本
├── bin/                          # mihomo 二进制文件
│   ├── clash-linux-amd64
│   ├── clash-linux-arm64
│   └── clash-linux-armv7
├── conf/                         # 运行时配置（自动生成）
│   ├── config.yaml
│   └── Country.mmdb
├── dashboard/public/             # YACD Dashboard 静态资源
├── logs/                         # 日志目录
├── scripts/
│   └── get_cpu_arch.sh           # CPU 架构检测
└── temp/
    ├── templete_config.yaml      # 配置模板（可自定义端口等）
    └── ...                       # 临时文件（自动生成）
```

## 自定义配置

编辑 `temp/templete_config.yaml` 可修改：

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| `port` | 7893 | HTTP 代理端口 |
| `socks-port` | 7894 | SOCKS5 代理端口 |
| `allow-lan` | true | 是否允许局域网设备使用代理 |
| `mode` | rule | 代理模式：rule / global / direct |
| `log-level` | info | 日志级别：silent / info / warning / error / debug |
| `external-controller` | 127.0.0.1:9091 | Dashboard API 监听地址 |

修改后重启生效：

```bash
bash shutdown.sh && bash start.sh
```

## 常见问题

**Q: 脚本报错 `-en [ OK ]`？**

部分系统默认 shell 为 `dash`，请使用 `bash start.sh` 运行。

**Q: 服务启动成功但代理不通？**

1. 检查端口是否在监听：`ss -tln | grep -E '9091|789.'`
2. 检查日志：`tail -f logs/clash.log`
3. 确认订阅地址有效且节点可用

**Q: 如何更换订阅？**

修改 `.env` 中的 `CLASH_URL`，然后重启：`bash shutdown.sh && bash start.sh`

## 致谢

- [mihomo (Clash.Meta)](https://github.com/MetaCubeX/mihomo)
- [YACD Dashboard](https://github.com/haishanh/yacd)
