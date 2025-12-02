#!/bin/bash

# 检查是否以root权限运行
if [ "$(id -u)" != "0" ]; then
   echo "此脚本必须以root权限运行" 
   exit 1
fi

# 询问节点位置
read -p "节点是否在中国大陆？(y/n): " in_china

# 设置下载源
if [[ "$in_china" =~ ^[Yy]$ ]]; then
    echo "使用GitHub镜像站下载"
    download_prefix="https://ghproxy.com/"
else
    echo "使用直接GitHub链接下载"
    download_prefix=""
fi

# 安装n2n
echo "正在下载并安装n2n..."
wget ${download_prefix}https://github.com/ntop/n2n/releases/download/3.1.1/n2n_3.1.1_amd64.deb
dpkg -i n2n_3.1.1_amd64.deb
apt-get install autoconf make gcc -y

# 设置工作目录
read -p "请输入easyn2n服务端目录（默认/opt）: " work_dir
work_dir=${work_dir:-/opt}

# 创建目录并下载源码
echo "正在设置easyn2n服务端..."
mkdir -p "$work_dir"
cd "$work_dir"

wget ${download_prefix}https://github.com/ntop/n2n/archive/refs/tags/3.0.tar.gz -O n2n-3.0.tar.gz
tar xzvf n2n-3.0.tar.gz
cd n2n-3.0

# 编译安装
./autogen.sh
./configure
make && make install

# 设置运行端口
read -p "请输入运行端口（默认7777）: " port
port=${port:-7777}

# 配置防火墙
echo "配置防火墙规则..."
ufw allow $port/udp

# 启动服务
echo "启动supernode服务..."
supernode -p $port > /dev/null 2>&1 &
sleep 2

# 获取本机IP
ip_address=$(hostname -I | awk '{print $1}')

# 显示结果
echo ""
echo "========================================"
echo " easyn2n节点部署成功！"
echo "----------------------------------------"
echo " 监听地址: $ip_address:$port"
echo " 连接方式: $ip_address:$port"
echo "----------------------------------------"
echo " 停止命令: sudo kill \$(pgrep supernode)"
echo "========================================"
echo ""

# 显示运行状态
echo "当前supernode进程状态:"
ps aux | grep supernode | grep -v grep
