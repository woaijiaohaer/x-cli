# portable-xray

[![GitHub Repo](https://img.shields.io/badge/GitHub-woaijiaohaer%2Fx--cli-181717?logo=github&logoColor=white)](https://github.com/woaijiaohaer/x-cli)
[![License: MIT](https://img.shields.io/badge/License-MIT-CC2936?logo=opensourceinitiative&logoColor=white)](LICENSE)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnubash&logoColor=white)](x-cli.sh)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20ARM-blue?logo=linux&logoColor=white)]()

一个轻量、开箱即用的 Xray VLESS Reality 一键管理脚本，支持交互式菜单与 CLI 两种使用方式。

---

## ⚠️ 免责声明 / Disclaimer

> **本项目仅供学习、研究和技术交流使用。**
>
> - 请遵守您所在地区及服务器所在地区的法律法规。
> - **严禁**将本项目用于任何违法违规用途，包括但不限于：突破法律限制、传播违禁内容、从事网络攻击等。
> - 因使用本项目所产生的一切法律责任，由使用者本人承担，作者不承担任何连带责任。
> - 本项目不提供任何代理服务，不鼓励、不支持任何违反当地法律的行为。

**This project is for educational and research purposes only. The author is not responsible for any misuse.**

---

## 功能特性

- **一键安装 / 卸载** Xray（自动适配最新版，兼容旧版 CPU）
- **VLESS + XTLS-Reality** 协议，伪装流量更安全
- **多架构支持**：`x86_64`、`aarch64 / arm64`、`armv7l`
- **多端口管理**：随时新增独立端口，各自拥有独立密钥
- **多用户管理**：为主端口添加用户，分配独立 UUID
- **防火墙自动放行**：自动配置 `iptables` / `ufw`
- **二维码输出**：终端直接显示 VLESS 链接二维码
- **诊断工具**：一键检查进程状态、端口监听、公网连通性
- **极简环境兼容**：没有 `apt` 时自动尝试 `dnf` / `yum` / `apk` / `pacman` / `zypper`，仅有 `curl` 或 `wget` 时也可继续安装
- **交互菜单 + CLI 双模式**：适合日常管理与脚本自动化

---

## 环境要求

| 项目 | 要求 |
|------|------|
| 操作系统 | 常见 Linux 发行版 |
| 权限 | root |
| 最低下载能力 | `curl` 或 `wget` 至少一个 |
| 依赖处理 | 优先使用系统包管理器自动安装；无包管理器时自动下载 `jq`；`qrencode` 缺失时仅不显示二维码 |

---

## 快速开始

### 下载脚本

```bash
# 用 wget（推荐）
wget -O x-cli.sh https://raw.githubusercontent.com/woaijiaohaer/x-cli/master/x-cli.sh

# 或用 curl
curl -fsSL -o x-cli.sh https://raw.githubusercontent.com/woaijiaohaer/x-cli/master/x-cli.sh

chmod +x x-cli.sh
```

### 交互式菜单（推荐）

```bash
sudo bash x-cli.sh
```

### CLI 直接安装

```bash
sudo bash x-cli.sh install
```

---

## CLI 命令一览

```
用法：bash x-cli.sh <命令> [参数]

命令：
  install           安装 Xray 并生成初始配置
  reinstall         卸载后重新安装（清空配置）
  update            重新生成配置（更换域名 & 密钥）
  uninstall         卸载 Xray（删除所有文件）

  add <用户名>       向主端口添加用户（新 UUID）
  add_port <端口>    新增独立 VLESS 端口（独立密钥）
  list              列出所有用户
  ports             查看所有端口及链接/二维码
  link              显示主端口客户端链接

  diag              诊断（进程/端口/防火墙/公网连通性）
  restart           重启 Xray
  status            查看运行状态
  stop              停止 Xray

  （无参数）          进入交互式菜单
```

---

## 交互菜单说明

```
  ╔═══════════════════════════════════════════╗
  ║       Xray VLESS Reality 管理脚本         ║
  ╚═══════════════════════════════════════════╝

  ── 安装管理 ──
  1) 安装 Xray
  2) 重新安装
  3) 更新配置（换域名/密钥）
  4) 卸载 Xray

  ── 端口 & 用户 ──
  5) 查看所有端口链接
  6) 新增端口
  7) 添加用户（到主端口）
  8) 查看用户列表

  ── 服务控制 ──
  9) 启动   10) 停止   11) 重启   12) 诊断

  0) 退出
```

---

## 客户端配置

安装完成后，脚本会自动输出 VLESS 链接及二维码，格式如下：

```
vless://<UUID>@<服务器IP>:<端口>?encryption=none&flow=xtls-rprx-vision
       &security=reality&sni=<伪装域名>&fp=chrome
       &pbk=<PublicKey>&sid=<ShortId>&type=tcp#VLESS-<端口>
```

将该链接导入支持 VLESS Reality 的客户端即可使用，例如：

- [v2rayN](https://github.com/2dust/v2rayN)（Windows）
- [v2rayNG](https://github.com/2dust/v2rayNG)（Android）
- [Shadowrocket](https://apps.apple.com/app/shadowrocket/id932747118)（iOS）
- [Nekoray](https://github.com/MatsuriDayo/nekoray)（Linux / Windows）
- [Hiddify](https://github.com/hiddify/hiddify-next)（跨平台）

> 配置信息同时保存于服务器 `/root/xray_config.txt`。

---

## 目录结构（安装后）

```
/usr/local/bin/xray              # Xray 主程序
/usr/local/etc/xray/config.json  # 配置文件
/usr/local/share/xray/geoip.dat  # GeoIP 数据
/var/log/xray/xray.log           # 运行日志
/etc/init.d/xray                 # 服务启动脚本
/root/xray_config.txt            # 连接信息摘要
```

---

## 常见问题

**Q：安装后无法连接？**
A：运行 `bash x-cli.sh diag` 查看诊断信息，重点检查"公网连通"一项，通常需要在云控制台/路由器中手动开放对应 TCP 端口的安全组/入站规则。

**Q：ARM 设备提示 SIGILL？**
A：脚本会自动降级安装兼容版本（v24.12.31 或 v1.8.23），无需手动干预。

**Q：如何更换伪装域名或重置密钥？**
A：执行 `bash x-cli.sh update`，脚本将随机选取新域名并重新生成 Reality 密钥对。

---

## License

[![License: MIT](https://img.shields.io/badge/License-MIT-CC2936?logo=opensourceinitiative&logoColor=white)](LICENSE)

Copyright © 2026 [woaijiaohaer](https://github.com/woaijiaohaer) — 本项目以 [MIT License](LICENSE) 开源发布，使用请遵守协议条款。

---

> 再次强调：**请在法律允许的范围内使用本项目，严禁用于任何违法用途。**
