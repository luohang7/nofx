#!/bin/bash
# NOFX Docker 启动脚本

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_message() {
    echo -e "${GREEN}[NOFX]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# 检查 Docker 是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi

    if ! command -v docker compose &> /dev/null && ! docker-compose --version &> /dev/null; then
        print_error "Docker Compose 未安装，请先安装 Docker Compose"
        exit 1
    fi
}

# 检查配置文件
check_config() {
    if [ ! -f "config.json" ]; then
        print_warning "config.json 不存在，正在创建..."
        if [ -f "config.json.example" ]; then
            cp config.json.example config.json
            print_message "已从 config.json.example 创建 config.json"
        else
            print_error "config.json.example 不存在"
            exit 1
        fi
    fi
}

# 启动服务
start_services() {
    print_info "启动 NOFX 服务..."

    if command -v docker compose &> /dev/null; then
        # 使用 Docker Compose V2
        docker compose up -d --build
    else
        # 使用 Docker Compose V1
        docker-compose up -d --build
    fi

    if [ $? -eq 0 ]; then
        print_message "服务启动成功！"
        print_message "Web 界面: http://localhost:3000"
        print_info "等待服务启动中..."
        sleep 10

        # 显示服务状态
        show_status
    else
        print_error "服务启动失败"
        exit 1
    fi
}

# 停止服务
stop_services() {
    print_info "停止 NOFX 服务..."

    if command -v docker compose &> /dev/null; then
        docker compose down
    else
        docker-compose down
    fi

    if [ $? -eq 0 ]; then
        print_message "服务已停止"
    else
        print_error "停止服务时出错"
    fi
}

# 显示日志
show_logs() {
    print_info "显示服务日志..."

    if command -v docker compose &> /dev/null; then
        docker compose logs -f
    else
        docker-compose logs -f
    fi
}

# 显示状态
show_status() {
    print_info "服务状态："

    if command -v docker compose &> /dev/null; then
        docker compose ps
    else
        docker-compose ps
    fi

    echo ""
    print_info "检查服务健康状态："
    sleep 2

    # 检查后端服务
    if curl -s http://localhost:8080/api/health > /dev/null 2>&1; then
        print_message "✓ 后端服务运行正常"
    else
        print_warning "✗ 后端服务可能未启动或无法访问"
    fi

    # 检查前端服务
    if curl -s http://localhost:3000 > /dev/null 2>&1; then
        print_message "✓ 前端服务运行正常"
    else
        print_warning "✗ 前端服务可能未启动或无法访问"
    fi
}

# 重启服务
restart_services() {
    print_info "重启 NOFX 服务..."
    stop_services
    sleep 5
    start_services
}

# 清理系统
clean_system() {
    print_warning "这将删除所有容器和镜像，确定继续吗？(y/N)"
    read -r response

    if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
        print_info "清理 Docker 资源..."

        if command -v docker compose &> /dev/null; then
            docker compose down -v --rmi all
        else
            docker-compose down -v --rmi all
        fi

        docker system prune -f
        print_message "清理完成"
    else
        print_info "取消清理"
    fi
}

# 显示帮助
show_help() {
    echo "NOFX Docker 管理脚本"
    echo ""
    echo "用法: $0 [命令]"
    echo ""
    echo "命令:"
    echo "  start      启动服务"
    echo "  stop       停止服务"
    echo "  restart    重启服务"
    echo "  logs       查看日志"
    echo "  status     查看状态"
    echo "  clean      清理所有数据（危险）"
    echo "  help       显示帮助"
    echo ""
}

# 主函数
main() {
    # 检查 Docker
    check_docker

    # 检查是否在正确的目录
    if [ ! -f "docker-compose.yml" ] && [ ! -f "docker-compose.yaml" ]; then
        print_error "请在 NOFX 项目根目录运行此脚本"
        exit 1
    fi

    # 处理命令
    case "${1:-help}" in
        "start")
            check_config
            start_services
            ;;
        "stop")
            stop_services
            ;;
        "restart")
            restart_services
            ;;
        "logs")
            show_logs
            ;;
        "status")
            show_status
            ;;
        "clean")
            clean_system
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            print_error "未知命令: $1"
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"