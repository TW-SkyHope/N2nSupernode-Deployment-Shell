#!/bin/bash

# 检测操作系统类型
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "无法确定操作系统类型"
    exit 1
fi

# 询问是否在中国大陆
read -p "节点是否在中国大陆？(y/n): " IN_CHINA
IN_CHINA=$(echo "$IN_CHINA" | tr '[:upper:]' '[:lower:]')

# 设置下载基础URL
if [[ "$IN_CHINA" == "y" || "$IN_CHINA" == "yes" ]]; then
    BASE_URL="https://gh.api.99988866.xyz/https://github.com"
else
    BASE_URL="https://github.com"
fi

# 安装n2n二进制包
install_n2n() {
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        PKG_NAME="n2n_3.1.1_amd64.deb"
        DOWNLOAD_URL="$BASE_URL/ntop/n2n/releases/download/3.1.1/$PKG_NAME"
        wget "$DOWNLOAD_URL"
        sudo dpkg -i "$PKG_NAME"
        rm -f "$PKG_NAME"
    elif [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "fedora" ]]; then
        PKG_NAME="n2n-3.1.1-1.x86_64.rpm"
        DOWNLOAD_URL="$BASE_URL/ntop/n2n/releases/download/3.1.1/$PKG_NAME"
        wget "$DOWNLOAD_URL"
        sudo rpm -ivh "$PKG_NAME"
        rm -f "$PKG_NAME"
    else
        echo "不支持的操作系统: $OS"
        exit 1
    fi
}

# 安装编译依赖
install_dependencies() {
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        sudo apt-get update
        sudo apt-get install autoconf make gcc -y
    elif [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "fedora" ]]; then
        sudo yum install autoconf make gcc -y
    fi
}

# 主程序
main() {
    # 安装n2n
    install_n2n
    
    # 安装依赖
    install_dependencies
    
    # 设置目录
    read -p "请输入EasyN2N服务端目录 (默认: /opt): " SERVER_DIR
    SERVER_DIR=${SERVER_DIR:-/opt}
    
    # 创建目录并进入
    sudo mkdir -p "$SERVER_DIR"
    cd "$SERVER_DIR" || exit
    
    # 下载并编译源码
    SOURCE_URL="$BASE_URL/ntop/n2n/archive/refs/tags/3.0.tar.gz"
    sudo wget "$SOURCE_URL"
    sudo tar xzvf 3.0.tar.gz
    cd n2n-3.0 || exit
    
    sudo ./autogen.sh
    sudo ./configure
    sudo make && sudo make install
    
    # 设置端口
    read -p "请输入运行端口: " PORT
    
    # 配置防火墙
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        sudo ufw allow "$PORT"/udp
    elif [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "fedora" ]]; then
        sudo firewall-cmd --permanent --add-port="$PORT"/udp
        sudo firewall-cmd --reload
    fi
    
    # 启动服务
    sudo supernode -p "$PORT" > /dev/null 2>&1 &
    SUPERNODE_PID=$!
    
    # 获取本机IP
    IP_ADDR=$(hostname -I | awk '{print $1}')
    
    # 输出结果
    echo ""
    echo "========================================"
    echo "  EasyN2N 服务端已成功启动！"
    echo "----------------------------------------"
    echo "  PID: $SUPERNODE_PID"
    echo "  监听端口: $PORT/udp"
    echo "  连接地址: $IP_ADDR:$PORT"
    echo "========================================"
    echo ""
    echo "关闭程序方法:"
    echo "1. 查找进程: ps -ef | grep supernode"
    echo "2. 终止进程: sudo kill <PID>"
    echo ""
}

# 执行主程序
main
    sudo apt-get update
    sudo apt-get install -y autoconf make gcc
elif [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "fedora" ]]; then
    pkg_name="n2n-3.1.1-1.x86_64.rpm"
    download_url="${proxy}https://github.com/ntop/n2n/releases/download/3.1.1/n2n-3.1.1-1.x86_64.rpm"
    wget "$download_url" -O "$pkg_name"
    sudo rpm -ivh "$pkg_name"
    sudo yum install -y autoconf make gcc
else
    echo "不支持的操作系统: $OS"
    exit 1
fi

# 下载并编译源码
src_url="${proxy}https://github.com/ntop/n2n/archive/refs/tags/3.0.tar.gz"
sudo wget "$src_url" -O "3.0.tar.gz"
sudo tar xzvf "3.0.tar.gz"
cd n2n-3.0 || exit 1
sudo ./autogen.sh
sudo ./configure
sudo make
sudo make install

# 设置运行端口
read -p "请输入运行端口（默认7777）: " port
port=${port:-7777}

# 配置防火墙
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    sudo ufw allow "$port"/udp
    sudo ufw reload
elif [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "fedora" ]]; then
    if command -v firewall-cmd &> /dev/null; then
        sudo firewall-cmd --permanent --add-port="$port"/udp
        sudo firewall-cmd --reload
    elif command -v iptables &> /dev/null; then
        sudo iptables -A INPUT -p udp --dport "$port" -j ACCEPT
        sudo service iptables save
    fi
fi

# 启动服务
sudo supernode -p "$port" > /dev/null 2>&1 &
sleep 2  # 等待进程启动

# 获取本机IP
ip=$(ip -o route get to 8.8.8.8 | sed -n 's/.*src \([0-9.]\+\).*/\1/p')

# 显示结果
echo ""
echo "========================================"
echo " easyn2n节点部署成功!"
echo "----------------------------------------"
echo " 监听端口: UDP/$port"
echo " 连接地址: $ip:$port"
echo "----------------------------------------"
echo " 查看运行状态: ps -ef | grep supernode"
echo " 关闭节点: sudo kill $(pgrep supernode)"
echo "========================================"
