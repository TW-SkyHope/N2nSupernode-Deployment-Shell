#!/bin/bash

# EasyN2N 部署管理脚本
# 支持 Ubuntu、Debian 和 RHEL 系系统

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检测系统类型
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME=$ID
        OS_VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        OS_NAME="rhel"
        OS_VERSION=$(cat /etc/redhat-release | sed -E 's/.* ([0-9]+)\..*/\1/')
    else
        log_error "无法检测操作系统类型"
        exit 1
    fi

    log_info "检测到操作系统: $OS_NAME $OS_VERSION"
}

# 安装依赖
install_dependencies() {
    log_info "安装系统依赖..."
    
    case $OS_NAME in
        ubuntu|debian)
            sudo apt-get update
            sudo apt-get install -y wget build-essential autoconf automake libtool \
                libssl-dev libpcap-dev net-tools pkg-config
            ;;
        rhel|centos|fedora)
            if command -v dnf &> /dev/null; then
                sudo dnf install -y wget gcc gcc-c++ make autoconf automake libtool \
                    openssl-devel libpcap-devel net-tools pkgconfig
            else
                sudo yum install -y wget gcc gcc-c++ make autoconf automake libtool \
                    openssl-devel libpcap-devel net-tools pkgconfig
            fi
            ;;
        *)
            log_error "不支持的操作系统: $OS_NAME"
            exit 1
            ;;
    esac
    
    log_success "依赖安装完成"
}

# 配置防火墙
configure_firewall() {
    local port=$1
    log_info "配置防火墙，开放端口 $port/udp"
    
    case $OS_NAME in
        ubuntu|debian)
            # 检查ufw是否安装并启用
            if command -v ufw &> /dev/null && sudo ufw status | grep -q "Status: active"; then
                sudo ufw allow $port/udp
                sudo ufw reload
            else
                log_warning "ufw未启用，请手动配置防火墙规则"
            fi
            ;;
        rhel|centos|fedora)
            # 检查firewalld
            if command -v firewall-cmd &> /dev/null && sudo firewall-cmd --state &> /dev/null; then
                sudo firewall-cmd --permanent --add-port=$port/udp
                sudo firewall-cmd --reload
            # 检查iptables
            elif command -v iptables &> /dev/null; then
                sudo iptables -A INPUT -p udp --dport $port -j ACCEPT
                # 对于RHEL/CentOS 7+，保存规则
                if command -v iptables-save &> /dev/null; then
                    sudo iptables-save | sudo tee /etc/sysconfig/iptables > /dev/null
                fi
            else
                log_warning "未找到防火墙服务，请手动配置防火墙规则"
            fi
            ;;
    esac
    
    log_success "防火墙配置完成"
}

# 下载n2n源码
download_n2n() {
    local install_path=$1
    local github_url=$2
    local filename="3.1.1.tar.gz"
    
    cd "$install_path"
    
    if [ -f "$filename" ]; then
        log_info "发现已存在的源码包，跳过下载"
    else
        log_info "下载 n2n 源码..."
        wget "$github_url" -O "$filename"
        if [ $? -ne 0 ]; then
            log_error "下载失败，请检查网络连接"
            exit 1
        fi
    fi
    
    # 解压源码
    log_info "解压源码包..."
    tar xzvf "$filename"
    
    log_success "源码下载和解压完成"
}

# 编译安装n2n
compile_install() {
    local install_path=$1
    
    cd "$install_path/n2n-3.1.1"
    
    log_info "开始编译安装 n2n..."
    
    # 生成配置脚本
    ./autogen.sh
    if [ $? -ne 0 ]; then
        log_error "autogen.sh 执行失败"
        exit 1
    fi
    
    # 配置编译选项
    ./configure
    if [ $? -ne 0 ]; then
        log_error "configure 执行失败"
        exit 1
    fi
    
    # 编译和安装
    make
    if [ $? -ne 0 ]; then
        log_error "make 编译失败"
        exit 1
    fi
    
    sudo make install
    if [ $? -ne 0 ]; then
        log_error "make install 安装失败"
        exit 1
    fi
    
    log_success "n2n 编译安装完成"
}

# 获取本机IP地址
get_ip_address() {
    local ip=""
    
    # 尝试多种方法获取IP
    if command -v ip &> /dev/null; then
        ip=$(ip route get 1 2>/dev/null | awk '{print $7; exit}') || true
    fi
    
    if [ -z "$ip" ] && command -v hostname &> /dev/null; then
        ip=$(hostname -I 2>/dev/null | awk '{print $1}') || true
    fi
    
    if [ -z "$ip" ]; then
        ip="<服务器IP地址>"
        log_warning "无法自动获取IP地址，请手动替换为实际IP"
    fi
    
    echo "$ip"
}

# 启动supernode
start_supernode() {
    local port=$1
    local ip=$(get_ip_address)
    
    log_info "启动 supernode 服务..."
    
    # 检查是否已有supernode进程在运行
    if pgrep -x "supernode" > /dev/null; then
        log_warning "发现已运行的supernode进程，先停止它们"
        stop_supernode
    fi
    
    # 启动supernode
    sudo supernode -p $port &
    local pid=$!
    
    # 等待进程启动
    sleep 2
    
    # 检查进程是否成功启动
    if ps -p $pid > /dev/null 2>&1; then
        log_success "supernode 启动成功 (PID: $pid)"
        echo "=================================================="
        log_succes        OS_VERSION=$VERSION_ID
    else
        log_error "无法检测操作系统类型"
        exit 1
    fi

    case $OS in
        ubuntu|debian)
            OS_TYPE="debian"
            log_info "检测到 Debian/Ubuntu 系统"
            ;;
        rhel|centos|fedora|rocky|almalinux)
            OS_TYPE="rhel"
            log_info "检测到 RHEL 架构系统"
            ;;
        *)
            log_error "不支持的操作系统: $OS"
            exit 1
            ;;
    esac
}

# 询问是否在中国大陆
ask_china_region() {
    while true; do
        read -p "节点是否在中国大陆？(y/n): " is_china
        case $is_china in
            [Yy]* )
                GITHUB_URL="https://hub.yzuu.cf"
                log_info "使用 GitHub 镜像站: $GITHUB_URL"
                break
                ;;
            [Nn]* )
                GITHUB_URL="https://github.com"
                log_info "使用 GitHub 原站: $GITHUB_URL"
                break
                ;;
            * ) echo "请输入 y 或 n";;
        esac
    done
}

# 询问安装目录
ask_install_dir() {
    read -p "设置 EasyN2N 服务端目录 (默认为 /opt): " install_dir
    install_dir=${install_dir:-/opt}
    log_info "安装目录: $install_dir"
}

# 询问运行端口
ask_port() {
    while true; do
        read -p "设置 EasyN2N 运行端口 (默认为 7654): " port
        port=${port:-7654}
        
        # 检查端口是否合法
        if [[ $port =~ ^[0-9]+$ ]] && [ $port -ge 1 ] && [ $port -le 65535 ]; then
            log_info "运行端口: $port"
            break
        else
            log_error "端口号必须为 1-65535 之间的数字"
        fi
    done
}

# 安装依赖 (Ubuntu/Debian)
install_dependencies_debian() {
    log_info "安装系统依赖..."
    sudo apt-get update
    sudo apt-get install -y autoconf make gcc wget
}

# 安装依赖 (RHEL/CentOS/Fedora)
install_dependencies_rhel() {
    log_info "安装系统依赖..."
    
    # 检查包管理器
    if command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y autoconf make gcc wget
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y autoconf make gcc wget
    else
        log_error "未找到可用的包管理器 (dnf/yum)"
        exit 1
    fi
}

# 安装 N2N 包 (Ubuntu/Debian)
install_n2n_package_debian() {
    log_info "下载并安装 N2N 包..."
    cd /tmp
    wget "${GITHUB_URL}/ntop/n2n/releases/download/3.1.1/n2n_3.1.1_amd64.deb"
    sudo dpkg -i n2n_3.1.1_amd64.deb || {
        log_warning "安装过程中可能存在依赖问题，尝试修复..."
        sudo apt-get install -f -y
    }
}

# 安装 N2N 包 (RHEL/CentOS/Fedora)
install_n2n_package_rhel() {
    log_info "下载并安装 N2N 包..."
    cd /tmp
    wget "${GITHUB_URL}/ntop/n2n/releases/download/3.1.1/n2n-3.1.1-1.x86_64.rpm"
    
    if command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y ./n2n-3.1.1-1.x86_64.rpm
    else
        sudo yum install -y ./n2n-3.1.1-1.x86_64.rpm
    fi
}

# 编译安装 EasyN2N
compile_easyn2n() {
    log_info "编译安装 EasyN2N..."
    
    # 创建安装目录
    sudo mkdir -p "$install_dir"
    cd "$install_dir"
    
    # 下载源码
    sudo wget "${GITHUB_URL}/ntop/n2n/archive/refs/tags/3.0.tar.gz"
    sudo tar xzvf 3.0.tar.gz
    cd n2n-3.0
    
    # 编译安装
    sudo ./autogen.sh
    sudo ./configure
    sudo make && sudo make install
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙..."
    
    case $OS_TYPE in
        debian)
            if command -v ufw >/dev/null 2>&1; then
                sudo ufw allow "$port/udp"
                log_success "UFW 防火墙已配置"
            else
                log_warning "未找到 ufw，请手动配置防火墙规则"
            fi
            ;;
        rhel)
            if command -v firewall-cmd >/dev/null 2>&1; then
                sudo firewall-cmd --permanent --add-port="$port/udp"
                sudo firewall-cmd --reload
                log_success "FirewallD 已配置"
            else
                log_warning "未找到 firewall-cmd，请手动配置防火墙规则"
            fi
            ;;
    esac
}

# 获取本机IP地址
get_ip_address() {
    # 尝试多种方法获取IP
    local ip
    ip=$(hostname -I | awk '{print $1}' 2>/dev/null) || 
    ip=$(ip route get 1 | awk '{print $7; exit}' 2>/dev/null) ||
    ip=$(curl -s ifconfig.me 2>/dev/null) ||
    ip="无法获取"
    
    echo "$ip"
}

# 启动 supernode 服务
start_supernode() {
    log_info "启动 supernode 服务..."
    
    # 获取IP地址
    local ip_address
    ip_address=$(get_ip_address)
    
    # 创建 systemd 服务文件
    local service_file="/etc/systemd/system/supernode.service"
    
    sudo tee "$service_file" > /dev/null <<EOF
[Unit]
Description=N2N Supernode
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/sbin/supernode -p $port
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    # 重新加载 systemd 并启动服务
    sudo systemc
