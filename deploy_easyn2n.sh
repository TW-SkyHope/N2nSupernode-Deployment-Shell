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
        log_success "EasyN2N 部署完成！"
        log_success "连接地址: $ip:$port"
        log_success "Supernode PID: $pid"
        echo "=================================================="
        
        # 保存PID到文件以便后续管理
        echo $pid > /tmp/easyn2n_supernode.pid
        log_info "PID已保存到 /tmp/easyn2n_supernode.pid"
    else
        log_error "supernode 启动失败"
        exit 1
    fi
}

# 停止supernode
stop_supernode() {
    log_info "停止 supernode 服务..."
    
    # 方法1: 使用保存的PID文件
    if [ -f /tmp/easyn2n_supernode.pid ]; then
        local pid=$(cat /tmp/easyn2n_supernode.pid)
        if ps -p $pid > /dev/null 2>&1; then
            sudo kill $pid
            log_success "已停止进程 (PID: $pid)"
            rm -f /tmp/easyn2n_supernode.pid
            return 0
        fi
    fi
    
    # 方法2: 查找并杀死所有supernode进程
    local pids=$(pgrep -x "supernode" 2>/dev/null || true)
    if [ -n "$pids" ]; then
        echo "$pids" | sudo xargs kill
        log_success "已停止所有supernode进程"
        rm -f /tmp/easyn2n_supernode.pid
    else
        log_warning "未找到运行的supernode进程"
    fi
}

# 显示状态
show_status() {
    log_info "检查 supernode 状态..."
    
    if [ -f /tmp/easyn2n_supernode.pid ]; then
        local pid=$(cat /tmp/easyn2n_supernode.pid)
        if ps -p $pid > /dev/null 2>&1; then
            log_success "supernode 正在运行 (PID: $pid)"
            local port=$(sudo netstat -tulpn 2>/dev/null | grep "$pid/supernode" | grep udp | awk '{print $4}' | cut -d: -f2)
            if [ -n "$port" ]; then
                local ip=$(get_ip_address)
                log_success "监听端口: $port"
                log_success "连接地址: $ip:$port"
            fi
            return 0
        else
            rm -f /tmp/easyn2n_supernode.pid
        fi
    fi
    
    local pids=$(pgrep -x "supernode" 2>/dev/null || true)
    if [ -n "$pids" ]; then
        log_success "supernode 正在运行 (PIDs: $pids)"
        # 显示端口信息
        sudo netstat -tulpn 2>/dev/null | grep supernode | grep udp || true
    else
        log_warning "supernode 未运行"
    fi
}

# 主部署函数
deploy_easyn2n() {
    log_info "开始部署 EasyN2N 节点..."
    
    # 检测操作系统
    detect_os
    
    # 询问是否在中国大陆
    read -p "节点是否在中国大陆？[y/N]: " in_china
    case $in_china in
        [Yy]* )
            GITHUB_URL="https://hub.yzuu.cf/ntop/n2n/archive/refs/tags/3.1.1.tar.gz"
            log_info "使用 GitHub 镜像站"
            ;;
        * )
            GITHUB_URL="https://github.com/ntop/n2n/archive/refs/tags/3.1.1.tar.gz"
            log_info "使用 GitHub 官方源"
            ;;
    esac
    
    # 询问安装路径
    read -p "请输入安装路径 [默认: /home]: " install_path
    install_path=${install_path:-/home}
    
    # 创建安装目录
    mkdir -p "$install_path"
    
    # 询问运行端口
    read -p "请输入 supernode 运行端口 [默认: 7654]: " run_port
    run_port=${run_port:-7654}
    
    # 验证端口号
    if ! [[ $run_port =~ ^[0-9]+$ ]] || [ $run_port -lt 1 ] || [ $run_port -gt 65535 ]; then
        log_error "无效的端口号: $run_port"
        exit 1
    fi
    
    log_info "安装路径: $install_path"
    log_info "运行端口: $run_port"
    
    # 安装依赖
    install_dependencies
    
    # 下载源码
    download_n2n "$install_path" "$GITHUB_URL"
    
    # 编译安装
    compile_install "$install_path"
    
    # 配置防火墙
    configure_firewall "$run_port"
    
    # 启动服务
    start_supernode "$run_port"
}

# 显示使用说明
show_usage() {
    echo "EasyN2N 部署管理脚本"
    echo ""
    echo "用法: $0 [命令]"
    echo ""
    echo "命令:"
    echo "  deploy    部署 EasyN2N 节点"
    echo "  start     启动 supernode 服务"
    echo "  stop      停止 supernode 服务"
    echo "  status    查看服务状态"
    echo "  restart   重启服务"
    echo "  help      显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 deploy    # 部署节点"
    echo "  $0 status    # 查看状态"
}

# 主程序
main() {
    case $1 in
        "deploy")
            deploy_easyn2n
            ;;
        "start")
            if [ -z "$2" ]; then
                log_error "请指定端口号，例如: $0 start 7654"
                exit 1
            fi
            start_supernode "$2"
            ;;
        "stop")
            stop_supernode
            ;;
        "status")
            show_status
            ;;
        "restart")
            if [ -z "$2" ]; then
                log_error "请指定端口号，例如: $0 restart 7654"
                exit 1
            fi
            stop_supernode
            sleep 2
            start_supernode "$2"
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            if [ $# -eq 0 ]; then
                show_usage
                echo ""
                read -p "是否开始部署？[Y/n]: " choice
                case $choice in
                    [Nn]* )
                        exit 0
                        ;;
                    * )
                        deploy_easyn2n
                        ;;
                esac
            else
                log_error "未知命令: $1"
                show_usage
                exit 1
            fi
            ;;
    esac
}

# 检查是否以root权限运行
if [ "$EUID" -eq 0 ]; then
    log_warning "不建议直接以root用户运行此脚本"
    read -p "是否继续？[y/N]: " root_continue
    case $root_continue in
        [Yy]* ) ;;
        * ) exit 1 ;;
    esac
fi

# 运行主程序
main "$@"
