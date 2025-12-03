#!/bin/bash

# 询问节点是否在中国大陆
read -p "节点是否在中国大陆？(y/n): " in_china

# 设置下载源
if [[ "$in_china" =~ ^[Yy]$ ]]; then
    github_prefix="https://mirror.ghproxy.com/https://github.com"
else
    github_prefix="https://github.com"
fi

# 检测操作系统类型
if [ -f /etc/redhat-release ]; then
    os_type="rhel"
elif [ -f /etc/lsb-release ]; then
    os_type="ubuntu"
else
    echo "无法识别的操作系统"
    exit 1
fi

# 安装n2n软件包
if [ "$os_type" == "ubuntu" ]; then
    wget "${github_prefix}/ntop/n2n/releases/download/3.1.1/n2n_3.1.1_amd64.deb" -O n2n.deb
    sudo dpkg -i n2n.deb
    rm n2n.deb
    pkg_manager="apt-get"
else
    wget "${github_prefix}/ntop/n2n/releases/download/3.1.1/n2n-3.1.1-1.x86_64.rpm" -O n2n.rpm
    sudo rpm -ivh n2n.rpm
    rm n2n.rpm
    pkg_manager="yum"
fi

# 安装编译工具
if [ "$os_type" == "ubuntu" ]; then
    sudo $pkg_manager install autoconf make gcc -y
else
    sudo $pkg_manager install autoconf make gcc -y
fi

# 设置服务端目录
read -p "设置easyn2n服务端目录（默认为/opt）: " server_dir
server_dir=${server_dir:-/opt}

# 创建目录并下载源码
sudo mkdir -p "$server_dir"
cd "$server_dir" || exit
sudo wget "${github_prefix}/ntop/n2n/archive/refs/tags/3.0.tar.gz" -O 3.0.tar.gz
sudo tar xzvf 3.0.tar.gz
rm 3.0.tar.gz

# 编译安装
cd n2n-3.0 || exit
sudo ./autogen.sh
sudo ./configure
sudo make
sudo make install

# 设置运行端口
read -p "设置easyn2n运行端口: " port

# 配置防火墙
if [ "$os_type" == "ubuntu" ]; then
    sudo ufw allow "$port"/udp
    sudo ufw reload
else
    sudo firewall-cmd --permanent --add-port="$port"/udp
    sudo firewall-cmd --reload
fi

# 启动服务
sudo supernode -p "$port" > /dev/null 2>&1 &
sleep 2

# 获取本机IP
ip_address=$(hostname -I | awk '{print $1}')

# 输出结果
echo ""
echo "========================================"
echo " easyn2n节点部署成功！"
echo "----------------------------------------"
echo " 运行状态: 运行中"
echo " 监听端口: $port/udp"
echo " 连接地址: ${ip_address}:${port}"
echo " 日志文件: /var/log/syslog (搜索supernode)"
echo "========================================"
echo ""
echo "关闭程序方法:"
echo "1. 查找进程ID: ps -ef | grep supernode"
echo "2. 终止进程: sudo kill <PID>"
echo "----------------------------------------"

# 清理临时文件
cd ~ || exit
