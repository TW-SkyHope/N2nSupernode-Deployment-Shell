#!/bin/bash

# EasyN2N 部署管理脚本
# 修复版本 - 解决语法错误问题

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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
    if ! command -v "$1" &> /dev/null; then
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
        check_command wget || { sudo apt-get update && sudo apt-get install -y wget; }
        sudo apt-get update
        sudo apt-get install -y autoconf make gcc
        
        log_info "下载n2n安装包..."
        wget "${GITHUB_MIRROR}https://github.com/ntop/n2n/releases/download/3.1.1/n2n_3.1.1_amd64.deb"
        sudo dpkg -i n2n_3.1.1_amd64.deb
        
    elif [ "$os_type" = "rhel" ]; then
        check_command wget || sudo yum install -y wget
        
        if command -v dnf &> /dev/null; then
            sudo dnf groupinstall -y "Development Tools"
            sudo dnf install -y autoconf make gcc
        else
            sudo yum groupinstall -y "Development Tools"
            sudo yum install -y autoconf make gcc
        fi
        
        log_info "下载n2n安装包..."
        wget "${GITHUB_MIRROR}https://github.com/ntop/n2n/releases/download/3.1.1/n2n-3.1.1-1.x86_64.rpm"
        sudo rpm -i n2n-3.1.1-1.x86_64.rpm
    fi
}

# 编译安装n2n源码
compile_n2n() {
    local install_dir=$1
    
    log_info "设置easyn2n服务端目录: $install_dir"
    cd "$install_dir" || { log_error "无法进入目录 $install_dir"; exit 1; }
    
    log_info "下载并编译n2n源码..."
    sudo wget "${GITHUB_MIRROR}https://github.com/ntop/n2n/archive/refs/tags/3.0.tar.gz"
    sudo tar xzvf 3.0.tar.gz
    cd n2n-3.0 || { log_error "无法进入n2n源码目录"; exit 1; }
    
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
        check_command ufw || sudo apt-get install -y ufw
        sudo ufw allow "$port"/udp
        sudo ufw --force enable
    elif [ "$os_type" = "rhel" ]; then
        if systemctl is-active --quiet firewalld; then
            sudo firewall-cmd --permanent --add-port="$port"/udp
            sudo firewall-cmd --reload
        else
            sudo iptables -A INPUT -p udp --dport "$port" -j ACCEPT
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
    
    if pgrep supernode > /dev/null; then
        log_warn "检测到已有supernode进程在运行，先停止..."
        sudo pkill supernode
        sleep 2
    fi
    
    sudo supernode -p "$port" &
    local pid=$!
    
    sleep 3
    
    if ps -p $pid > /dev/null 2>&1; then
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
        local port=$(sudo netstat -tulpn 2>/dev/null | grep supernode | grep udp | awk '{print $4}' | cut -d: -f2)
        local ip_addr=$(hostname -I | awk '{print $1}')
        log_info "✅ supernode正在运行 (PID: $pid)"
        log_info "📡 连接地址: $ip_addr:${port:-未知}"
    else
        log_info "❌ supernode未运行"
    fi
}

# 部署节点
