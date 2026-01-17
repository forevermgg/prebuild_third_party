#!/bin/bash
set -u
# 增强错误检测：任何命令失败、管道失败、尝试使用未定义变量都会导致脚本退出
set -euo pipefail

# 脚本配置
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 颜色输出函数
print_info() { echo -e "\033[1;34m[INFO] $*\033[0m"; }
print_success() { echo -e "\033[1;32m[SUCCESS] $*\033[0m"; }
print_warning() { echo -e "\033[1;33m[WARNING] $*\033[0m"; }
print_error() { echo -e "\033[1;31m[ERROR] $*\033[0m" >&2; }

# 清理函数（确保脚本退出时也能清理）
cleanup() {
    if [ -d "$BUILD_DIR" ]; then
        print_info "Cleaning up build directory: $BUILD_DIR"
        rm -rf "$BUILD_DIR"
    fi
}

# 捕获退出信号执行清理
trap cleanup EXIT

# ======================================================================
# 1. 参数验证与变量定义
# ======================================================================

# 检查参数数量
if [ "$#" -ne 3 ]; then
    print_error "Usage: $SCRIPT_NAME <NDK_ROOT_PATH> <API_LEVEL> <COMMA_SEPARATED_ABIS>"
    print_error "Example: $SCRIPT_NAME /path/to/ndk 24 arm64-v8a,armeabi-v7a"
    exit 1
fi

# 参数赋值
readonly NDK_ROOT="$1"
readonly API_LEVEL="$2"
readonly TARGET_ABIS_STR="$3"

# c-ares 配置（版本、仓库地址）
readonly C_ARES_VERSION="1.34.5"
readonly C_ARES_REPO="https://github.com/c-ares/c-ares"
readonly C_ARES_SRC_DIR="c-ares"  # 克隆后的目录名

# 目标目录 (使用绝对路径作为基准)
readonly PREFIX_DIR="$SCRIPT_DIR/prefix/c-ares"
readonly BUILD_DIR="$SCRIPT_DIR/build_cares_android"

# 将逗号分隔的 ABI 字符串转换为 Bash 数组
IFS=',' read -r -a ABIS <<< "$TARGET_ABIS_STR"

# 检查 NDK 有效性
if [ ! -d "$NDK_ROOT/toolchains/llvm/prebuilt" ]; then
    print_error "Invalid NDK root directory: $NDK_ROOT"
    exit 1
fi

print_info "--- Starting c-ares Android Build (Static Lib .a) ---"
print_info "NDK Root: $NDK_ROOT"
print_info "Target API Level: $API_LEVEL"
print_info "Target ABIs: ${ABIS[*]}"
print_info "c-ares Version: ${C_ARES_VERSION}"
print_info "-----------------------------------"

# 清理构建目录
print_info "Cleaning up previous build directory: $BUILD_DIR"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# 清理安装目录
print_info "Cleaning up installation directory: $PREFIX_DIR"
rm -rf "$PREFIX_DIR"
mkdir -p "$PREFIX_DIR"

# ======================================================================
# 2. 克隆/更新 c-ares 源码并切换到指定标签
# ======================================================================

print_info "Preparing c-ares source code (version: v$C_ARES_VERSION)..."

# 检查源码目录是否存在
if [ -d "$BUILD_DIR/$C_ARES_SRC_DIR" ]; then
    print_info "Existing source directory found. Checking repository and version..."

    # 进入源码目录检查远程仓库和当前分支
    cd "$BUILD_DIR/$C_ARES_SRC_DIR"

    # 获取当前远程仓库URL
    CURRENT_REPO=$(git remote get-url origin 2>/dev/null || true)

    # 获取当前检出的版本
    CURRENT_TAG=$(git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD)

    # 检查是否是正确的仓库和版本
    if [ "$CURRENT_REPO" != "$C_ARES_REPO" ] || [ "$CURRENT_TAG" != "v$C_ARES_VERSION" ]; then
        print_warning "Repository mismatch or incorrect version found. Recloning..."
        cd "$BUILD_DIR"
        rm -rf "$C_ARES_SRC_DIR"
    else
        print_info "Repository and version are correct. Updating..."
        git fetch --tags
        git checkout "v$C_ARES_VERSION"
        cd "$SCRIPT_DIR"
    fi
fi

# 如果源码目录不存在，则克隆
if [ ! -d "$BUILD_DIR/$C_ARES_SRC_DIR" ]; then
    print_info "Cloning c-ares repository..."
    cd "$BUILD_DIR"
    git clone "$C_ARES_REPO" "$C_ARES_SRC_DIR"

    cd "$C_ARES_SRC_DIR"
    # 检查标签是否存在
    if ! git rev-parse "v$C_ARES_VERSION" >/dev/null 2>&1; then
        print_error "Tag v$C_ARES_VERSION does not exist in the repository!"
        print_info "Available tags:"
        git tag -l | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | tail -10
        exit 1
    fi

    git checkout "v$C_ARES_VERSION"
fi

# 验证源码目录结构
if [ ! -d "$BUILD_DIR/$C_ARES_SRC_DIR/src" ]; then
    print_error "Failed to clone c-ares source or invalid repository structure!"
    exit 1
fi

cd "$SCRIPT_DIR"  # 返回脚本目录

# ======================================================================
# 3. 交叉编译循环（按 ABI 逐个编译）
# ======================================================================

for ABI in "${ABIS[@]}"; do
    print_info "=========================================="
    print_info "Building c-ares for ABI: $ABI"
    print_info "=========================================="

    # 1. 配置 NDK 工具链（根据 ABI 选择对应的编译器）
    case "$ABI" in
        arm64-v8a)
            HOST="aarch64-linux-android"
            ;;
        armeabi-v7a)
            HOST="armv7a-linux-androideabi"
            ;;
        x86)
            HOST="i686-linux-android"
            ;;
        x86_64)
            HOST="x86_64-linux-android"
            ;;
        *)
            print_error "Unsupported ABI: $ABI"
            exit 1
            ;;
    esac

    # 拼接编译器路径（NDK llvm 工具链）
    # 自动检测 NDK 预编译目录（支持 macOS/Linux）
    if [ -d "$NDK_ROOT/toolchains/llvm/prebuilt/darwin-arm64" ]; then
        NDK_PREBUILT_DIR="$NDK_ROOT/toolchains/llvm/prebuilt/darwin-arm64"
    elif [ -d "$NDK_ROOT/toolchains/llvm/prebuilt/darwin-x86_64" ]; then
        NDK_PREBUILT_DIR="$NDK_ROOT/toolchains/llvm/prebuilt/darwin-x86_64"
    elif [ -d "$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64" ]; then
        NDK_PREBUILT_DIR="$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64"
    else
        print_error "NDK prebuilt directory not found!"
        exit 1
    fi

    CC="$NDK_PREBUILT_DIR/bin/${HOST}${API_LEVEL}-clang"
    CXX="$NDK_PREBUILT_DIR/bin/${HOST}${API_LEVEL}-clang++"
    AR="$NDK_PREBUILT_DIR/bin/llvm-ar"
    RANLIB="$NDK_PREBUILT_DIR/bin/llvm-ranlib"

    # 检查编译器是否存在
    if [ ! -f "$CC" ]; then
        print_error "Compiler not found: $CC"
        exit 1
    fi
    print_info "Compiler CC = $CC"

    # 2. 为当前 ABI 创建构建和安装目录（使用非只读变量）
    ABI_BUILD_DIR="$BUILD_DIR/$ABI"
    ABI_PREFIX_DIR="$PREFIX_DIR/$ABI"
    mkdir -p "$ABI_BUILD_DIR"
    mkdir -p "$ABI_PREFIX_DIR"

    # 获取绝对路径（确保目录已存在）
    ABI_PREFIX_DIR_ABS="$(realpath "$ABI_PREFIX_DIR")"
    print_info "ABI_PREFIX_DIR = $ABI_PREFIX_DIR_ABS"

    # 3. 进入源码目录，配置编译参数
    cd "$BUILD_DIR/$C_ARES_SRC_DIR"

    # 生成配置脚本（c-ares 使用 autotools，需要先执行 autoreconf）
    print_info "Generating configuration scripts for $ABI..."
    autoreconf -fi

    print_info "Configuring c-ares for $ABI..."
    PKG_CONFIG_PATH="$ABI_PREFIX_DIR_ABS/lib/pkgconfig" \
    LD_LIBRARY_PATH="$ABI_PREFIX_DIR_ABS/lib" \
    CC="$CC" \
    CXX="$CXX" \
    AR="$AR" \
    RANLIB="$RANLIB" \
    ./configure \
        --host="$HOST" \
        --prefix="$ABI_PREFIX_DIR_ABS" \
        --enable-static \
        --enable-shared \
        --disable-tests \
        --enable-debug \
        --with-random=/dev/urandom

    # 4. 编译并安装
    print_info "Building c-ares for $ABI..."
    make clean
    make -j$(sysctl -n hw.ncpu 2>/dev/null || nproc)

    print_info "Installing c-ares for $ABI..."
    make install

    # 5. 验证安装结果（检查静态库是否存在）
    if [ ! -f "$ABI_PREFIX_DIR_ABS/lib/libcares.a" ]; then
        print_error "Build failed: libcares.a not found for $ABI at $ABI_PREFIX_DIR_ABS/lib/"
        exit 1
    fi

    print_success "Successfully built and installed c-ares for $ABI"
    cd "$SCRIPT_DIR"  # 返回脚本目录
done

# ======================================================================
# 4. 结论
# ======================================================================
print_info "--------------------------------------------------------"
print_success "c-ares Android Build Completed Successfully for all target ABIs!"
print_info "Static libraries (.a) are installed in: $PREFIX_DIR"
print_info "--------------------------------------------------------"

# 手动触发清理（trap 也会执行，但这里显式调用更清晰）
cleanup