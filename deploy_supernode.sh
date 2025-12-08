#!/bin/bash

# n2n节点管理脚本
# 适配Debian和Red Hat Enterprise Linux架构

echo "========================================"
echo "n2n节点管理脚本"
echo "========================================"

# 检测系统类型
detect_system() {
    if [ -f /etc/debian_version ]; then
        SYSTEM="debian"
    elif [ -f /etc/redhat-release ]; then
        SYSTEM="redhat"
    else
        echo "错误：不支持的系统类型"
        exit 1
    fi
    echo "检测到系统类型：$SYSTEM"
}

# 安装依赖包
install_dependencies() {
    echo "正在安装依赖包..."
    if [ "$SYSTEM" = "debian" ]; then
        sudo apt-get update
        sudo apt-get install -y build-essential git wget libssl-dev
    elif [ "$SYSTEM" = "redhat" ]; then
        sudo yum update -y
        sudo yum groupinstall -y "Development Tools"
        sudo yum install -y git wget openssl-devel
    fi
}

# 安装n2n节点
install_n2n() {
    # 选择安装目录
    read -p "请输入安装目录 [默认: /opt/n2n]: " INSTALL_DIR
    INSTALL_DIR=${INSTALL_DIR:-/opt/n2n}
    
    # 创建安装目录
    sudo mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR" || exit 1
    
    # 下载并编译安装
    echo "正在下载n2n源码..."
    wget https://github.com/ntop/n2n/archive/refs/tags/3.0.tar.gz
    
    echo "正在解压源码..."
    tar xzvf 3.0.tar.gz
    
    cd n2n-3.0 || exit 1
    
    echo "正在编译安装..."
    ./autogen.sh
    ./configure
    make && sudo make install
    
    # 清理安装包
    cd "$INSTALL_DIR" || exit 1
    rm -f 3.0.tar.gz
    
    echo "n2n supernode安装完成！"
}

# 启动supernode
start_supernode() {
    # 检查是否已安装
    if ! command -v supernode &> /dev/null; then
        echo "错误：supernode未安装，请先执行安装操作"
        return 1
    fi
    
    # 设置运行端口
    read -p "请输入supernode运行端口 [默认: 7654]: " PORT
    PORT=${PORT:-7654}
    
    # 配置防火墙
    echo "正在配置防火墙..."
    if [ "$SYSTEM" = "debian" ]; then
        sudo ufw allow "$PORT"/udp
    elif [ "$SYSTEM" = "redhat" ]; then
        # 检测防火墙类型
        if command -v firewalld &> /dev/null; then
            sudo firewall-cmd --permanent --add-port="$PORT"/udp
            sudo firewall-cmd --reload
        elif command -v iptables &> /dev/null; then
            sudo iptables -A INPUT -p udp --dport "$PORT" -j ACCEPT
            # 保存iptables规则（根据系统不同）
            if command -v service &> /dev/null; then
                sudo service iptables save
            elif command -v iptables-save &> /dev/null; then
                sudo iptables-save > /etc/sysconfig/iptables
            fi
        fi
    fi
    
    # 启动supernode
    echo "正在启动supernode..."
    sudo supernode -p "$PORT" -d
    
    # 输出运行信息
    echo "========================================"
    echo "supernode启动成功！"
    echo "连接地址：$(hostname -I | awk '{print $1}'):$PORT"
    echo "========================================"
}

# 停止supernode
stop_supernode() {
    echo "正在停止supernode..."
    # 查找supernode进程
    PID=$(ps -ef | grep "supernode" | grep -v grep | awk '{print $2}')
    
    if [ -n "$PID" ]; then
        sudo kill "$PID"
        echo "supernode已停止"
    else
        echo "supernode未运行"
    fi
}

# 查看supernode状态
status_supernode() {
    echo "正在查看supernode状态..."
    PID=$(ps -ef | grep "supernode" | grep -v grep | awk '{print $2}')
    
    if [ -n "$PID" ]; then
        echo "supernode正在运行，PID: $PID"
        echo "监听端口：$(sudo netstat -tuln | grep "supernode" | awk '{print $4}' | awk -F: '{print $NF}')"
    else
        echo "supernode未运行"
    fi
}

# 主菜单
show_menu() {
    echo ""
    echo "请选择操作："
    echo "1. 安装n2n supernode"
    echo "2. 启动supernode"
    echo "3. 停止supernode"
    echo "4. 查看supernode状态"
    echo "5. 退出"
    echo ""
}

# 主程序
detect_system

while true; do
    show_menu
    read -p "请输入选项 [1-5]: " CHOICE
    
    case $CHOICE in
        1)
            install_dependencies
            install_n2n
            ;;
        2)
            start_supernode
            ;;
        3)
            stop_supernode
            ;;
        4)
            status_supernode
            ;;
        5)
            echo "感谢使用，再见！"
            exit 0
            ;;
        *)
            echo "错误：无效选项，请重新输入"
            ;;
    esac
done
