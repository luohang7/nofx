#!/bin/sh

# ═══════════════════════════════════════════════════════════════
# NOFX AI Trading System - Docker Quick Start Script (ash compatible)
# Usage: ./run.sh [command]
# ═══════════════════════════════════════════════════════════════

# ------------------------------------------------------------------------
# Color Definitions
# ------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ------------------------------------------------------------------------
# Utility Functions: Colored Output
# ------------------------------------------------------------------------
print_info() {
    printf "${BLUE}[INFO]${NC} %s\n" "$1"
}

print_success() {
    printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"
}

print_warning() {
    printf "${YELLOW}[WARNING]${NC} %s\n" "$1"
}

print_error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1"
}

# ------------------------------------------------------------------------
# Detection: Docker Compose Command (Backward Compatible)
# ------------------------------------------------------------------------
detect_compose_cmd() {
    if command -v docker compose >/dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        COMPOSE_CMD="docker-compose"
    else
        print_error "Docker Compose 未安装！请先安装 Docker Compose"
        exit 1
    fi
    print_info "使用 Docker Compose 命令: $COMPOSE_CMD"
}

# ------------------------------------------------------------------------
# Validation: Docker Installation
# ------------------------------------------------------------------------
check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        print_error "Docker 未安装！请先安装 Docker: https://docs.docker.com/get-docker/"
        exit 1
    fi

    detect_compose_cmd
    print_success "Docker 和 Docker Compose 已安装"
}

# ------------------------------------------------------------------------
# Validation: Environment File (.env)
# ------------------------------------------------------------------------
check_env() {
    if [ ! -f ".env" ]; then
        print_warning ".env 不存在，从模板复制..."
        cp .env.example .env
        print_info "✓ 已使用默认环境变量创建 .env"
        print_info "💡 如需修改端口等设置，可编辑 .env 文件"
    fi
    print_success "环境变量文件存在"
}

# ------------------------------------------------------------------------
# Validation: Encryption Environment (RSA Keys + Data Encryption Key)
# ------------------------------------------------------------------------
check_encryption() {
    need_setup=0

    print_info "检查加密环境..."

    # 检查RSA密钥对
    if [ ! -f "secrets/rsa_key" ] || [ ! -f "secrets/rsa_key.pub" ]; then
        print_warning "RSA密钥对不存在"
        need_setup=1
    fi

    # 检查数据加密密钥
    if [ ! -f ".env" ] || ! grep -q "^DATA_ENCRYPTION_KEY=" .env; then
        print_warning "数据加密密钥未配置"
        need_setup=1
    fi

    # 检查JWT认证密钥
    if [ ! -f ".env" ] || ! grep -q "^JWT_SECRET=" .env; then
        print_warning "JWT认证密钥未配置"
        need_setup=1
    fi

    # 如果需要设置加密环境
    if [ "$need_setup" -eq 1 ]; then
        print_info "🔐 检测到加密环境未配置，正在自动设置..."

        if [ -f "scripts/setup_encryption.sh" ]; then
            # 使用 ash 运行脚本
            printf "Y\nn\nn\n" | ash scripts/setup_encryption.sh
            if [ $? -eq 0 ]; then
                print_success "🔐 加密环境设置完成！"
                print_info "  • RSA-2048密钥对已生成"
                print_info "  • AES-256数据加密密钥已配置"
                print_info "  • JWT认证密钥已配置"
                print_info "  • 所有敏感数据现在都受加密保护"
            else
                print_error "加密环境设置失败"
                exit 1
            fi
        else
            print_error "加密设置脚本不存在: scripts/setup_encryption.sh"
            print_info "请手动运行: ash scripts/setup_encryption.sh"
            exit 1
        fi
    else
        print_success "🔐 加密环境已配置"
        print_info "  • RSA密钥对: secrets/rsa_key + secrets/rsa_key.pub"
        print_info "  • 数据加密密钥: .env (DATA_ENCRYPTION_KEY)"
        print_info "  • JWT认证密钥: .env (JWT_SECRET)"

        # 修复权限
        if [ -f "secrets/rsa_key" ]; then
            chmod 600 secrets/rsa_key
        fi
        if [ -f ".env" ]; then
            chmod 600 .env
        fi
    fi
}

# ------------------------------------------------------------------------
# Validation: Configuration File (config.json)
# ------------------------------------------------------------------------
check_config() {
    if [ ! -f "config.json" ]; then
        print_warning "config.json 不存在，从模板复制..."
        cp config.json.example config.json
        print_info "✓ 已使用默认配置创建 config.json"
        print_info "💡 如需修改基础设置，可编辑 config.json"
        print_info "💡 模型/交易所/交易员配置请使用Web界面"
    fi
    print_success "配置文件存在"
}

# ------------------------------------------------------------------------
# Utility: Read Environment Variables
# ------------------------------------------------------------------------
read_env_vars() {
    if [ -f ".env" ]; then
        NOFX_FRONTEND_PORT=$(grep "^NOFX_FRONTEND_PORT=" .env 2>/dev/null | cut -d'=' -f2)
        NOFX_BACKEND_PORT=$(grep "^NOFX_BACKEND_PORT=" .env 2>/dev/null | cut -d'=' -f2)

        # 去除引号和空格
        NOFX_FRONTEND_PORT=$(echo "$NOFX_FRONTEND_PORT" | tr -d '"' | tr -d "'")
        NOFX_BACKEND_PORT=$(echo "$NOFX_BACKEND_PORT" | tr -d '"' | tr -d "'")

        # 如果为空则使用默认值
        : ${NOFX_FRONTEND_PORT:=3000}
        : ${NOFX_BACKEND_PORT:=8080}
    else
        NOFX_FRONTEND_PORT=3000
        NOFX_BACKEND_PORT=8080
    fi
}

# ------------------------------------------------------------------------
# Validation: Database File (config.db)
# ------------------------------------------------------------------------
check_database() {
    if [ -d "config.db" ]; then
        print_warning "config.db 是目录而非文件，正在删除目录..."
        rm -rf config.db
        touch config.db
        chmod 600 config.db
        print_info "✓ 已创建空数据库文件（权限: 600）"
    elif [ ! -f "config.db" ]; then
        print_warning "数据库文件不存在，创建空数据库文件..."
        touch config.db
        chmod 600 config.db
        print_info "✓ 已创建空数据库文件（权限: 600）"
    else
        print_success "数据库文件存在"
    fi
}

# ------------------------------------------------------------------------
# Service Management: Start (without --build)
# ------------------------------------------------------------------------
start() {
    print_info "正在启动 NOFX AI Trading System..."

    # 读取环境变量
    read_env_vars

    # 确保必要的文件和目录存在
    if [ ! -f "config.db" ]; then
        print_info "创建数据库文件..."
        touch config.db
        chmod 600 config.db
    fi
    if [ ! -d "decision_logs" ]; then
        print_info "创建日志目录..."
        mkdir -p decision_logs
        chmod 700 decision_logs
    fi

    # 启动容器（不构建）
    print_info "启动容器..."
    $COMPOSE_CMD up -d

    print_success "服务已启动！"
    print_info "Web 界面: http://localhost:${NOFX_FRONTEND_PORT}"
    print_info "API 端点: http://localhost:${NOFX_BACKEND_PORT}"
    print_info ""
    print_info "查看日志: ./run.sh logs"
    print_info "停止服务: ./run.sh stop"
}

# ------------------------------------------------------------------------
# Service Management: Stop
# ------------------------------------------------------------------------
stop() {
    print_info "正在停止服务..."
    $COMPOSE_CMD stop
    print_success "服务已停止"
}

# ------------------------------------------------------------------------
# Service Management: Restart
# ------------------------------------------------------------------------
restart() {
    print_info "正在重启服务..."
    $COMPOSE_CMD restart
    print_success "服务已重启"
}

# ------------------------------------------------------------------------
# Monitoring: Logs
# ------------------------------------------------------------------------
logs() {
    if [ -z "$2" ]; then
        $COMPOSE_CMD logs -f
    else
        $COMPOSE_CMD logs -f "$2"
    fi
}

# ------------------------------------------------------------------------
# Monitoring: Status
# ------------------------------------------------------------------------
status() {
    # 读取环境变量
    read_env_vars

    print_info "服务状态:"
    $COMPOSE_CMD ps
    echo ""
    print_info "健康检查:"
    curl -s "http://localhost:${NOFX_BACKEND_PORT}/api/health" 2>/dev/null || echo "后端未响应"
}

# ------------------------------------------------------------------------
# Maintenance: Clean (Destructive)
# ------------------------------------------------------------------------
clean() {
    print_warning "这将删除所有容器和数据！"
    printf "确认删除？(yes/no): "
    read confirm
    if [ "$confirm" = "yes" ]; then
        print_info "正在清理..."
        $COMPOSE_CMD down -v
        print_success "清理完成"
    else
        print_info "已取消"
    fi
}

# ------------------------------------------------------------------------
# Maintenance: Update (without build)
# ------------------------------------------------------------------------
update() {
    print_info "正在更新..."
    git pull
    $COMPOSE_CMD up -d
    print_success "更新完成"
}

# ------------------------------------------------------------------------
# Encryption: Manual Setup
# ------------------------------------------------------------------------
setup_encryption_manual() {
    print_info "🔐 手动设置加密环境"

    if [ -f "scripts/setup_encryption.sh" ]; then
        ash scripts/setup_encryption.sh
    else
        print_error "加密设置脚本不存在: scripts/setup_encryption.sh"
        print_info "请确保项目文件完整"
        exit 1
    fi
}

# ------------------------------------------------------------------------
# Help: Usage Information
# ------------------------------------------------------------------------
show_help() {
    echo "NOFX AI Trading System - Docker 管理脚本 (ash版本)"
    echo ""
    echo "用法: ./run.sh [command] [options]"
    echo ""
    echo "命令:"
    echo "  start              启动服务"
    echo "  stop               停止服务"
    echo "  restart            重启服务"
    echo "  logs [service]     查看日志（可选：指定服务名 backend/frontend）"
    echo "  status             查看服务状态"
    echo "  clean              清理所有容器和数据"
    echo "  update             更新代码并重启"
    echo "  setup-encryption   设置加密环境（RSA密钥+数据加密）"
    echo "  help               显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  ./run.sh start              # 启动服务"
    echo "  ./run.sh logs backend       # 查看后端日志"
    echo "  ./run.sh status            # 查看状态"
    echo "  ./run.sh setup-encryption  # 手动设置加密环境"
    echo ""
    echo "🔐 关于加密:"
    echo "  系统自动检测加密环境，首次运行时会自动设置"
    echo "  手动设置: ash scripts/setup_encryption.sh"
    echo ""
    echo "⚠️  注意: 镜像需要单独使用 'docker-compose build' 或 'docker compose build' 构建"
}

# ------------------------------------------------------------------------
# Main: Command Dispatcher
# ------------------------------------------------------------------------
main() {
    check_docker

    case "${1:-start}" in
        start)
            check_env
            check_encryption
            check_config
            check_database
            start "$2"
            ;;
        stop)
            stop
            ;;
        restart)
            restart
            ;;
        logs)
            logs "$@"
            ;;
        status)
            status
            ;;
        clean)
            clean
            ;;
        update)
            update
            ;;
        setup-encryption)
            setup_encryption_manual
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "未知命令: $1"
            show_help
            exit 1
            ;;
    esac
}

# Execute Main
main "$@"