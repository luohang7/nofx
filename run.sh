#!/bin/sh

# NOFX Docker 启动脚本 - 兼容 ash shell

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 打印消息
print_info() {
    echo "${GREEN}[NOFX]${NC} $1"
}

print_error() {
    echo "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo "${YELLOW}[WARNING]${NC} $1"
}

# 检查 Docker
check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        print_error "Docker 未安装"
        exit 1
    fi
}

# 启动服务
start_services() {
    print_info "启动 NOFX 服务..."

    # 检查配置文件
    if [ ! -f "config.json" ]; then
        if [ -f "config.json.example" ]; then
            cp config.json.example config.json
            print_info "已创建 config.json"
        fi
    fi

    # 尝试 docker compose 或 docker-compose
    if command -v docker-compose >/dev/null 2>&1; then
        docker-compose up -d --build
    elif docker compose version >/dev/null 2>&1; then
        docker compose up -d --build
    else
        print_error "Docker Compose 未安装"
        exit 1
    fi

    if [ $? -eq 0 ]; then
        print_info "服务启动成功！"
        print_info "Web 界面: http://localhost:3000"
        sleep 5
        show_status
    else
        print_error "启动失败"
        exit 1
    fi
}

# 停止服务
stop_services() {
    print_info "停止服务..."
    if command -v docker-compose >/dev/null 2>&1; then
        docker-compose down
    else
        docker compose down
    fi
}

# 查看状态
show_status() {
    print_info "服务状态："
    if command -v docker-compose >/dev/null 2>&1; then
        docker-compose ps
    else
        docker compose ps
    fi
}

# 查看日志
show_logs() {
    print_info "显示日志..."
    if command -v docker-compose >/dev/null 2>&1; then
        docker-compose logs -f
    else
        docker compose logs -f
    fi
}

# 主逻辑
case "$1" in
    start)
        check_docker
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        stop_services
        sleep 3
        start_services
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    *)
        echo "用法: $0 {start|stop|restart|status|logs}"
        echo ""
        echo "命令:"
        echo "  start   - 启动服务"
        echo "  stop    - 停止服务"
        echo "  restart - 重启服务"
        echo "  status  - 查看状态"
        echo "  logs    - 查看日志"
        exit 1
        ;;
esac