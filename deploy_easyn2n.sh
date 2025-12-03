#!/bin/bash

# EasyN2N 部署管理脚本
# 支持 Ubuntu/Debian 和 RHEL/CentOS/Fedora 系统

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检测系统类型
detect_os() {
    if [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/redhat-release ] || [ -f /etc/centos-release ] || [ -f /etc/fedora-release ]; then
        echo "rhel"
    else
        log_error "不支持的Linux发行版"
        exit 1
    fi
}

# 检查命令是否存在
check_command() {
    if ! command -v $1 &> /dev/null; then
        log_error "命令 $1 未找到，请先安装"
        return 1
    fi
    return 0
}

# 询问是否在中国大陆
ask_location() {
    read -p "节点是否在中国大陆？(y/n): " is_china
    case $is_china in
        [Yy]* )
            GITHUB_MIRROR="https://ghproxy.com/"
            log_info "使用GitHub镜像站"
            ;;
        [Nn]* )
            GITHUB_MIRROR=""
            log_info "使用原始GitHub链接"
            ;;
        * )
            log_warn "输入无效，默认使用原始GitHub链接"
            GITHUB_MIRROR=""
            ;;
    esac
}

# 安装依赖和n2n包
install_dependencies() {
    local os_type=$1
    
    log_info "开始安装依赖..."
    
    if [ "$os_type" = "debian" ]; then
        # Debian/Ubuntu 系统
        check_command wget || sudo apt-get update && sudo apt-get install -y wget
        sudo apt-get update
        sudo apt-get install -y autoconf make gcc
        
        # 下载并安装n2n包
        log_info "下载n2n安装包..."
        wget ${GITHUB_MIRROR}https://github.com/ntop/n2n/releases/download/3.1.1/n2n_3.1.1_amd64.deb
        sudo dpkg -i n2n_3.1.1_amd64.deb
        
    elif [ "$os_type" = "rhel" ]; then
        # RHEL/CentOS/Fedora 系统
        check_command wget || sudo yum install -y wget
        
        # 安装开发工具
        if command -v dnf &> /dev/null; then
            sudo dnf groupinstall -y "Development Tools"
            sudo dnf install -y autoconf make gcc
        else
            sudo yum groupinstall -y "Development Tools"
            sudo yum install -y autoconf make gcc
        fi
        
        # 下载并安装n2n包
        log_info "下载n2n安装包..."
        wget ${GITHUB_MIRROR}https://github.com/ntop/n2n/releases/download/3.1.1/n2n-3.1.1-1.x86_64.rpm
        sudo rpm -i n2n-3.1.1-1.x86_64.rpm
    fi
}

# 编译安装n2n源码
compile_n2n() {
    local install_dir=$1
    
    log_info "设置easyn2n服务端目录: $install_dir"
    cd $install_dir
    
    log_info "下载并编译n2n源码..."
    sudo wget ${GITHUB_MIRROR}https://github.com/ntop/n2n/archive/refs/tags/3.0.tar.gz
    sudo tar xzvf 3.0.tar.gz
    cd n2n-3.0
    
    log_info "开始编译安装..."
    sudo ./autogen.sh
    sudo ./configure
    sudo make && sudo make install
    
    log_info "n2n编译安装完成"
}

# 配置防火墙
configure_firewall() {
    local port=$1
    local os_type=$2
    
    log_info "配置防火墙，开放端口 $port/udp"
    
    if [ "$os_type" = "debian" ]; then
        # Debian/Ubuntu 使用ufw
        check_command ufw || sudo apt-get install -y ufw
        sudo ufw allow $port/udp
        sudo ufw --force enable
    elif [ "$os_type" = "rhel" ]; then
        # RHEL/CentOS 使用firewalld
        if systemctl is-active --quiet firewalld; then
            sudo firewall-cmd --permanent --add-port=$port/udp
            sudo firewall-cmd --reload
        else
            # 如果没有firewalld，使用iptables
            sudo iptables -A INPUT -p udp --dport $port -j ACCEPT
            # 保存iptables规则（根据系统不同）
            if command -v iptables-save &> /dev/null; then
                sudo iptables-save > /etc/sysconfig/iptables 2>/dev/null || \
                sudo iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
            fi
        fi
    fi
}

# 启动supernode服务
start_supernode() {
    local port=$1
    
    log_info "启动supernode服务，端口: $port"
    
    # 检查是否已有supernode进程在运行
    if pgrep supernode > /dev/null; then
        log_warn "检测到已有supernode进程在运行，先停止..."
        sudo pkill supernode
        sleep 2
    fi
    
    # 启动supernode
    sudo supernode -p $port &
    local pid=$!
    
    sleep 3
    
    # 检查是否启动成功
    if ps -p $pid > /dev/null; then
        local ip_addr=$(hostname -I | awk '{print $1}')
        log_info "════════════════════════════════════════"
        log_info "🎉 EasyN2N 启动成功！"
        log_info "📡 连接地址: $ip_addr:$port"
        log_info "📊 进程PID: $pid"
        log_info "════════════════════════════════════════"
    else
        log_error "supernode启动失败，请检查日志"
        return 1
    fi
}

# 停止supernode服务
stop_supernode() {
    log_info "停止supernode服务..."
    
    if pgrep supernode > /dev/null; then
        sudo pkill supernode
        log_info "supernode已停止"
    else
        log_warn "没有找到运行的supernode进程"
    fi
}

# 显示运行状态
show_status() {
    log_info "当前supernode进程状态:"
    ps -ef | grep supernode | grep -v grep
    
    if pgrep supernode > /dev/null; then
        local pid=$(pgrep supernode)
        local port=$(sudo netstat -tulpn 2>/dev/null | grep supernode | grep udp | awk '{prin        sudo apt-get install -y n2n
    elif [[ "$OS" =~ (rhel|centos|fedora|alinux) ]]; then
        sudo yum install -y epel-release
        sudo yum install -y n2n
    else
        echo "不支持的操作系统: $OS"
        exit 1
    fi
}

# 编译安装n2n
compile_n2n() {
    install_dependencies
    
    # 设置目录
    read -p "设置easyn2n服务端目录(默认/opt): " work_dir
    work_dir=${work_dir:-/opt}
    sudo mkdir -p "$work_dir"
    cd "$work_dir" || exit
    
    # 下载并编译源码
    sudo wget "${BASE_URL}/ntop/n2n/archive/refs/tags/3.0.tar.gz" -O n2n.tar.gz
    sudo tar xzvf n2n.tar.gz
    cd n2n-3.0 || exit
    sudo ./autogen.sh
    sudo ./configure
    sudo make && sudo make install
}

# 安装编译依赖
install_dependencies() {
    if [[ "$OS" =~ (ubuntu|debian) ]]; then
        sudo apt-get update
        sudo apt-get install -y autoconf make gcc libssl-dev
    elif [[ "$OS" =~ (rhel|centos|fedora|alinux) ]]; then
        sudo yum groupinstall -y "Development Tools"
        sudo yum install -y openssl-devel
    fi
}

# 主程序
main() {
    # 优先尝试包管理器安装
    if install_n2n; then
        echo "通过包管理器安装n2n成功"
    else
        echo "包管理器安装失败，尝试源码编译..."
        compile_n2n
    fi

    # 设置端口
    read -p "设置easyn2n运行端口(默认7654): " port
    port=${port:-7654}
    
    # 配置防火墙
    if command -v ufw &> /dev/null; then
        sudo ufw allow "$port"/udp
    elif command -v firewall-cmd &> /dev/null; then
        sudo firewall-cmd --add-port="$port"/udp --permanent
        sudo firewall-cmd --reload
    else
        echo "警告: 无法自动配置防火墙，请手动开放端口 $port/udp"
    fi
    
    # 启动服务
    sudo pkill supernode 2>/dev/null
    sudo supernode -p "$port" > /dev/null 2>&1 &
    sleep 2
    
    # 获取IP地址
    ip_addr=$(ip -o route get 8.8.8.8 | sed -n 's/.*src \([0-9.]\+\).*/\1/p')
    
    # 输出结果
    echo ""
    echo "========================================"
    echo " easyn2n 节点部署成功!"
    echo "========================================"
    echo "监听地址: ${ip_addr}:${port}"
    echo "连接命令: edge -a 虚拟IP -c 组名 -k 密码 -l ${ip_addr}:${port}"
    echo "========================================"
    echo "管理命令:"
    echo "  启动: sudo supernode -p $port"
    echo "  停止: sudo pkill supernode"
    echo "========================================"
}

# 执行主程序
main
        exit 1
    fi
}

# 安装编译依赖
install_dependencies() {
    if [[ "$OS" =~ (ubuntu|debian) ]]; then
        sudo apt-get update
        sudo apt-get install -y autoconf make gcc
    elif [[ "$OS" =~ (rhel|centos|fedora) ]]; then
        sudo yum install -y autoconf make gcc
    fi
}

# 主程序
main() {
    # 安装预编译包
    install_prebuilt
    
    # 安装依赖
    install_dependencies
    
    # 设置目录
    read -p "设置easyn2n服务端目录(默认/opt): " work_dir
    work_dir=${work_dir:-/opt}
    sudo mkdir -p "$work_dir"
    cd "$work_dir" || exit
    
    # 下载并编译源码
    sudo wget "${BASE_URL}/ntop/n2n/archive/refs/tags/3.0.tar.gz"
    sudo tar xzvf 3.0.tar.gz
    cd n2n-3.0 || exit
    sudo ./autogen.sh
    sudo ./configure
    sudo make && sudo make install
    
    # 设置端口
    read -p "设置easyn2n运行端口: " port
    sudo ufw allow "$port"/udp 2>/dev/null || \
        sudo firewall-cmd --add-port="$port"/udp --permanent 2>/dev/null || \
        echo "警告: 无法自动配置防火墙，请手动开放端口 $port/udp"
    
    # 启动服务
    sudo supernode -p "$port" > /dev/null 2>&1 &
    sleep 2
    
    # 获取IP地址
    ip_addr=$(ip -o route get 8.8.8.8 | sed -n 's/.*src \([0-9.]\+\).*/\1/p')
    
    # 输出结果
    echo ""
    echo "========================================"
    echo " easyn2n 节点部署成功!"
    echo "========================================"
    echo "监听地址: ${ip_addr}:${port}"
    echo "连接命令: edge -a 虚拟IP -c 组名 -k 密码 -l ${ip_addr}:${port}"
    echo "========================================"
    echo "关闭命令: sudo kill \$(ps -ef | grep 'supernode' | grep -v grep | awk '{print \$2}')"
    echo "========================================"
}

# 执行主程序
main
        exit 1
    fi
}

# 安装n2n
install_n2n() {
    local pkg_name
    if [[ "$OS_NAME" == "ubuntu" || "$OS_NAME" == "debian" ]]; then
        pkg_name="n2n_3.1.1_amd64.deb"
        wget "${GITHUB_PREFIX}ntop/n2n/releases/download/3.1.1/$pkg_name"
        sudo dpkg -i "$pkg_name"
        rm -f "$pkg_name"
    else
        pkg_name="n2n-3.1.1-1.x86_64.rpm"
        wget "${GITHUB_PREFIX}ntop/n2n/releases/download/3.1.1/$pkg_name"
        sudo rpm -ivh "$pkg_name"
        rm -f "$pkg_name"
    fi
}

# 编译安装supernode
compile_supernode() {
    read -p "设置easyn2n服务端目录(默认/opt): " SERVER_DIR
    SERVER_DIR=${SERVER_DIR:-/opt}
    
    sudo mkdir -p "$SERVER_DIR"
    cd "$SERVER_DIR" || exit
    
    local tar_file="3.0.tar.gz"
    wget "${GITHUB_PREFIX}ntop/n2n/archive/refs/tags/$tar_file"
    sudo tar xzvf "$tar_file"
    cd n2n-3.0 || exit
    
    sudo ./autogen.sh
    sudo ./configure
    sudo make
    sudo make install
}

# 启动服务
start_service() {
    read -p "设置easyn2n运行端口: " PORT
    
    # 开放防火墙端口
    if [[ "$OS_NAME" == "ubuntu" || "$OS_NAME" == "debian" ]]; then
        sudo ufw allow "$PORT"/udp
        sudo ufw reload
    else
        sudo firewall-cmd --permanent --add-port="$PORT"/udp
        sudo firewall-cmd --reload
    fi
    
    # 启动supernode
    sudo supernode -p "$PORT" > /dev/null 2>&1 &
    
    # 获取IP地址
    IP_ADDR=14545
    
    echo ""
    echo "========================================"
    echo "运行成功！"
    echo "连接地址: $IP_ADDR:$PORT"
    echo "========================================"
    echo "要停止服务，请运行: sudo kill \$(pgrep supernode)"
    echo "========================================"
}

# 主流程
main() {
    install_dependencies
    install_n2n
    compile_supernode
    start_service
}

main
