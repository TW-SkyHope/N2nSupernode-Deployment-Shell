#!/bin/bash

# 询问节点是否在中国大陆
echo "请选择节点所在地区："
echo "1) 中国大陆"
echo "2) 非中国大陆"
read -p "请输入选择 (1/2): " region_choice

if [ "$region_choice" = "1" ]; then
    use_mirror=true
    echo "使用国内镜像站"
else
    use_mirror=false
    echo "使用官方GitHub链接"
fi

# 设置下载前缀
if [ "$use_mirror" = true ]; then
    github_prefix="https://mirror.ghproxy.com/https://github.com"
else
    github_prefix="https://github.com"
fi

# 检测操作系统
detect_os() {
    if [ -f /etc/redhat-release ]; then
        echo "rhel"
    elif [ -f /etc/lsb-release ] || grep -q "Ubuntu" /etc/issue; then
        echo "ubuntu"
    else
        echo "unknown"
    fi
}

os_type=$(detect_os)

if [ "$os_type" = "unknown" ]; then
    echo "错误：无法识别的操作系统"
    exit 1
fi

echo "检测到操作系统: $os_type"

# 安装n2n二进制包
echo "正在下载并安装n2n二进制包..."
if [ "$os_type" = "ubuntu" ]; then
    # Ubuntu系统
    wget "${github_prefix}/ntop/n2n/releases/download/3.1.1/n2n_3.1.1_amd64.deb"
    sudo dpkg -i n2n_3.1.1_amd64.deb
    # 修复可能的依赖问题
    sudo apt-get install -f -y
    # 安装编译工具
    sudo apt-get install autoconf make gcc -y
else
    # Red Hat Enterprise Linux系统
    wget "${github_prefix}/ntop/n2n/releases/download/3.1.1/n2n-3.1.1-1.x86_64.rpm"
    sudo rpm -ivh n2n-3.1.1-1.x86_64.rpm
    # 安装编译工具
    sudo yum install autoconf make gcc -y
fi

# 设置easyn2n服务端目录
read -p "设置easyn2n服务端目录(不写默认为/opt): " server_dir
if [ -z "$server_dir" ]; then
    server_dir="/opt"
    echo "使用默认目录: $server_dir"
fi

# 创建目录并进入
sudo mkdir -p "$server_dir"
cd "$server_dir" || { echo "无法进入目录 $server_dir"; exit 1; }

# 下载源码
echo "正在下载n2n源码..."
sudo wget "${github_prefix}/ntop/n2n/archive/refs/tags/3.0.tar.gz"
sudo tar xzvf 3.0.tar.gz

# 编译安装
echo "正在编译安装..."
cd n2n-3.0 || { echo "无法进入n2n-3.0目录"; exit 1; }
sudo ./autogen.sh
sudo ./configure
sudo make && sudo make install

# 设置easyn2n运行端口
read -p "设置easyn2n运行端口: " port

# 配置防火墙
if [ "$os_type" = "ubuntu" ]; then
    # Ubuntu使用ufw
    sudo ufw allow "$port"/udp
    echo "已允许UDP端口 $port"
else
    # RHEL使用firewalld
    sudo firewall-cmd --permanent --add-port="$port"/udp
    sudo firewall-cmd --reload
    echo "已允许UDP端口 $port"
fi

# 启动supernode
echo "正在启动supernode..."
sudo supernode -p "$port" &

# 等待进程启动
sleep 2

# 获取本机IP地址
ip_address=$(hostname -I | awk '{print $1}')

# 输出运行成功信息
echo ""
echo "=========================================="
echo "easyn2n节点部署成功！"
echo "=========================================="
echo "运行状态: 运行中"
echo "监听端口: $port/udp"
echo "连接地址: ${ip_address}:${port}"
echo "进程PID: $(pgrep -f 'supernode -p')"
echo "=========================================="
echo ""

# 显示关闭程序的方法
echo "关闭程序方法："
echo "1. 查看进程: ps -ef | grep supernode"
echo "2. 根据PID杀死进程: sudo kill <PID>"
echo ""
echo "或者运行以下命令一键关闭："
echo "sudo pkill -f 'supernode -p'"
echo "=========================================="

# 清理下载的安装包（可选）
cd ..
rm -f n2n_3.1.1_amd64.deb n2n-3.1.1-1.x86_64.rpm 3.0.tar.gz
