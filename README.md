# Easyn2nServer-Deployment-Shell
在linux下一键部署Easyn2n服务端的脚本
一个用于部署和管理 easyn2n 节点的交互式 shell 脚本，支持 Debian 和 Red Hat Enterprise Linux 架构。

## 功能特性

- 🔍 **自动系统检测**：自动识别 Debian 或 Red Hat 架构
- 📦 **依赖自动安装**：根据系统类型安装所需编译依赖
- 🚀 **一键安装**：交互式选择安装目录，自动完成 easyn2n 编译安装
- 🔥 **智能防火墙配置**：自动配置 ufw、firewalld 或 iptables
- 🎯 **灵活端口设置**：支持自定义 supernode 运行端口
- 📊 **状态监控**：实时查看 supernode 运行状态
- 🛑 **安全停止**：根据 PID 安全终止 supernode 进程

## 系统要求

### 支持的操作系统

- **Debian 架构**：Ubuntu 16.04+、Debian 8+ 等
- **Red Hat 架构**：CentOS 7+、RHEL 7+、Fedora 22+ 等

### 必要条件

- 具有 sudo 权限的用户
- 网络连接（用于下载源码和依赖）
- 基本的 Linux 命令行知识

## 快速开始

```bash
wget -O deploy_easyn2n.sh  "https://raw.githubusercontent.com/TW-SkyHope/Easyn2nServer-Deployment-Shell/main/deploy_easyn2n.sh" && chmod +x deploy_easyn2n.sh && ./deploy_easyn2n.sh
```

## 使用指南

### 主菜单

脚本运行后会显示主菜单：

```
========================================
easyn2n节点管理脚本
========================================
检测到系统类型：debian

请选择操作：
1. 安装easyn2n
2. 启动supernode
3. 停止supernode
4. 查看supernode状态
5. 退出
```

### 1. 安装 easyn2n

选择选项 `1` 开始安装流程：

1. 输入安装目录（默认：`/opt/easyn2n`）
2. 脚本会自动：
   - 安装编译依赖
   - 下载 easyn2n 3.0 源码
   - 解压并编译安装
   - 清理安装包

### 2. 启动 supernode

选择选项 `2` 启动 supernode 服务：

1. 输入运行端口（默认：`7654`）
2. 脚本会自动：
   - 配置防火墙规则
   - 启动 supernode 服务
   - 显示连接地址信息

### 3. 停止 supernode

选择选项 `3` 停止正在运行的 supernode 服务：

- 脚本会自动查找并杀死 supernode 进程

### 4. 查看 supernode 状态

选择选项 `4` 查看 supernode 运行状态：

- 显示是否正在运行
- 显示进程 ID
- 显示监听端口

## 防火墙配置

脚本会根据系统类型自动配置防火墙：

### Debian 系统（ufw）

```bash
sudo ufw allow <port>/udp
```

### Red Hat 系统（firewalld）

```bash
sudo firewall-cmd --permanent --add-port=<port>/udp
sudo firewall-cmd --reload
```

### Red Hat 系统（iptables）

```bash
sudo iptables -A INPUT -p udp --dport <port> -j ACCEPT
sudo iptables-save > /etc/sysconfig/iptables
```

## 常见问题

### Q: 脚本无法检测到系统类型？
A: 请确保您的系统是 Debian 或 Red Hat 架构的 Linux 发行版。(emmmmm，阿里的alinux你们自己改下也能用)

### Q: 编译安装失败？
A: 请检查：
- 网络连接是否正常
- 是否具有足够的磁盘空间
- 是否安装了所有必要的依赖

### Q: supernode 无法启动？
A: 请检查：
- 端口是否已被占用
- 防火墙是否正确配置
- 是否具有 sudo 权限

### Q: 如何修改已运行的 supernode 端口？
A: 请先停止当前服务，然后重新启动并选择新端口。

### 运行命令

```bash
# 启动 supernode（后台运行）
sudo supernode -p <port> -d

# 查看运行状态
ps -ef | grep supernode

# 停止服务
sudo kill <pid>
```

---

<h3>
  
  > 注意事项：用的n2n是3.0版本的！
</h3>

<h3>若您正在使用我的项目对我的项目有新的需求或发现bug请向于本项目内报告，一般3-7天内会给出答复，后期可能会视作品小星星der数量增加更多功能！由于此项目时效性，我会每隔2-4月进行运行测试是否可正常运行</h3>

<h3>作者的话：卧槽，TRAE真tm好用，之前用腾讯元宝都在吃大便，亏老子还给她开发个接口</h3>****
