#!/bin/bash

# Mises MCP Bridge 一键安装脚本
# 使用方式: curl -fsSL https://raw.githubusercontent.com/greasedev/mcp-chrome/master/app/native-server/install.sh | sh

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
REPO_URL="${REPO_URL:-https://github.com/greasedev/mcp-chrome.git}"
LOCAL_SOURCE="${LOCAL_SOURCE:-}"  # 本地源代码路径，用于测试
INSTALL_DIR=""
TEMP_DIR=""

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 清理函数
cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        log_info "清理临时目录..."
        rm -rf "$TEMP_DIR"
    fi
}

# 设置 trap
trap cleanup EXIT

# 检测操作系统和设置安装目录
detect_os() {
    case "$(uname -s)" in
        Darwin*)
            OS="macos"
            # 使用用户指定的目录
            INSTALL_DIR="$HOME/Library/Application Support/MisesSoftware/Mises-Browser/NativeMessagingHosts/mcp"
            ;;
        Linux*)
            OS="linux"
            INSTALL_DIR="$HOME/.local/share/MisesSoftware/Mises-Browser/NativeMessagingHosts/mcp"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            OS="windows"
            INSTALL_DIR="$APPDATA/MisesSoftware/Mises-Browser/NativeMessagingHosts/mcp"
            ;;
        *)
            log_error "不支持的操作系统: $(uname -s)"
            exit 1
            ;;
    esac
    log_info "检测到操作系统: $OS"
    log_info "安装目录: $INSTALL_DIR"
}

# 检查 Node.js
check_node() {
    if ! command -v node &> /dev/null; then
        log_error "未找到 Node.js，请先安装 Node.js 20+"
        log_info "推荐使用 nvm 安装: curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash"
        exit 1
    fi

    NODE_VERSION=$(node -v | sed 's/v//' | cut -d'.' -f1)
    if [ "$NODE_VERSION" -lt 20 ]; then
        log_error "Node.js 版本过低 (当前: v$(node -v))，需要 20+"
        exit 1
    fi

    log_success "Node.js 版本: $(node -v)"
}

# 检查 npm
check_npm() {
    if ! command -v npm &> /dev/null; then
        log_error "未找到 npm"
        exit 1
    fi
    log_success "npm 版本: $(npm -v)"
}

# 检查 git
check_git() {
    if ! command -v git &> /dev/null; then
        log_error "未找到 git，请先安装 git"
        exit 1
    fi
}

# 下载并构建
download_and_build() {
    TEMP_DIR=$(mktemp -d)
    log_info "创建临时目录: $TEMP_DIR"

    # 支持本地源代码路径（用于测试）
    if [ -n "$LOCAL_SOURCE" ] && [ -d "$LOCAL_SOURCE" ]; then
        log_info "使用本地源代码: $LOCAL_SOURCE"
        cp -r "$LOCAL_SOURCE" "$TEMP_DIR/repo"
    else
        log_info "克隆仓库..."
        git clone --depth 1 "$REPO_URL" "$TEMP_DIR/repo"
    fi

    cd "$TEMP_DIR/repo/app/native-server"

    log_info "安装构建依赖..."
    npm install --ignore-scripts

    log_info "构建项目（包含运行时依赖）..."
    npm run build:native

    log_success "构建完成"
}

# 安装到目标目录
install_to_target() {
    log_info "安装到: $INSTALL_DIR"

    # 如果目录已存在，备份旧版本
    if [ -d "$INSTALL_DIR" ]; then
        BACKUP_DIR="$INSTALL_DIR.backup.$(date +%Y%m%d%H%M%S)"
        log_warn "发现旧版本，备份到: $BACKUP_DIR"
        mv "$INSTALL_DIR" "$BACKUP_DIR"
    fi

    # 创建目标目录的父目录
    mkdir -p "$(dirname "$INSTALL_DIR")"

    # 复制构建产物到目标目录
    cd "$TEMP_DIR/repo/app/native-server"
    cp -r dist "$INSTALL_DIR"

    log_success "安装完成"
}

# 创建可执行脚本包装器
create_wrapper() {
    log_info "创建可执行脚本..."

    # 创建 bin 目录
    mkdir -p "$INSTALL_DIR/bin"

    # 创建 mcp-mises-bridge 包装脚本
    cat > "$INSTALL_DIR/bin/mcp-mises-bridge" << 'WRAPPER'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec node "$SCRIPT_DIR/../cli.js" "$@"
WRAPPER
    chmod +x "$INSTALL_DIR/bin/mcp-mises-bridge"

    # 创建 mises-mcp-bridge 链接
    ln -sf mcp-mises-bridge "$INSTALL_DIR/bin/mises-mcp-bridge"

    log_success "可执行脚本创建完成"
}

# 注册 Native Messaging Host
register_native_host() {
    log_info "注册 Native Messaging Host..."

    cd "$INSTALL_DIR"

    # 运行注册命令（注册全部浏览器）
    node cli.js register

    log_success "Native Messaging Host 注册完成"
}

# 修复权限
fix_permissions() {
    log_info "修复文件权限..."

    cd "$INSTALL_DIR"

    # 运行 fix-permissions 命令（如果存在）
    node cli.js fix-permissions 2>/dev/null || true

    # 确保 cli.js 和 index.js 有执行权限
    chmod +x cli.js index.js 2>/dev/null || true

    log_success "权限修复完成"
}

# 打印安装信息
print_info() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}   Mises MCP Bridge 安装成功!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "安装目录: ${BLUE}$INSTALL_DIR${NC}"
    echo ""
    echo "常用命令:"
    echo "  查看版本:    node $INSTALL_DIR/cli.js --version"
    echo "  重新注册:    node $INSTALL_DIR/cli.js register -b mises"
    echo "  诊断问题:    node $INSTALL_DIR/cli.js doctor"
    echo "  修复权限:    node $INSTALL_DIR/cli.js fix-permissions"
    echo ""
    echo "卸载方法:"
    echo "  rm -rf \"$INSTALL_DIR\""
    echo ""
}

# 主函数
main() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   Mises MCP Bridge 一键安装脚本${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    # 检查环境
    log_info "检查环境..."
    detect_os
    check_node
    check_npm
    check_git

    # 下载并构建
    download_and_build

    # 安装
    install_to_target

    # 创建包装脚本
    create_wrapper

    # 注册
    register_native_host

    # 修复权限
    fix_permissions

    # 打印信息
    print_info
}

# 运行
main "$@"