#!/bin/bash

# EasyN2N 部署管理脚本
# 支持 Ubuntu 和 RHEL 架构系统

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

# 检查系统类型
check_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
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
