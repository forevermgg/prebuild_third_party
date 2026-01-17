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

# 捕获退出信号执行清理（正常退出/异常退出都会执行）
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

# Zstd 配置（版本、仓库地址）
readonly ZSTD_VERSION="1.5.6"  # 稳定版，可根据需要修改
readonly ZSTD_REPO="https://github.com/facebook/zstd"
readonly ZSTD_SRC_DIR="$SCRIPT_DIR/zstd"  # 使用绝对路径，避免目录切换问题
readonly PREFIX_DIR="$SCRIPT_DIR/prefix/zstd"
readonly BUILD_DIR="$SCRIPT_DIR/build_zstd_android"

# NDK CMake 工具链文件路径
readonly TOOLCHAIN_FILE="$NDK_ROOT/build/cmake/android.toolchain.cmake"

# 将逗号分隔的 ABI 字符串转换为 Bash 数组
IFS=',' read -r -a ABIS <<< "$TARGET_ABIS_STR"

# 检查关键文件和目录
if [ ! -f "$TOOLCHAIN_FILE" ]; then
    print_error "NDK Toolchain file not found at: $TOOLCHAIN_FILE"
    print_error "Please check your NDK path and ensure it's a valid Android NDK installation."
    exit 1
fi

# ======================================================================
# 2. 克隆/更新 zstd 源码并切换到指定版本
# ======================================================================

print_info "Preparing zstd source code (version: v$ZSTD_VERSION)..."

# 检查源码目录是否存在
if [ -d "$ZSTD_SRC_DIR" ]; then
    print_info "Existing source directory found. Checking repository and version..."

    # 进入源码目录检查远程仓库和当前分支
    cd "$ZSTD_SRC_DIR"

    # 获取当前远程仓库URL
    CURRENT_REPO=$(git remote get-url origin 2>/dev/null || true)

    # 获取当前检出的版本
    CURRENT_TAG=$(git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD)

    # 检查是否是正确的仓库和版本
    if [ "$CURRENT_REPO" != "$ZSTD_REPO" ] || [ "$CURRENT_TAG" != "v$ZSTD_VERSION" ]; then
        print_warning "Repository mismatch or incorrect version found. Recloning..."
        cd "$SCRIPT_DIR"
        rm -rf "$ZSTD_SRC_DIR"
    else
        print_info "Repository and version are correct. Updating..."
        git fetch --tags
        git checkout "v$ZSTD_VERSION"
        cd "$SCRIPT_DIR"
    fi
fi

# 如果源码目录不存在，则克隆
if [ ! -d "$ZSTD_SRC_DIR" ]; then
    print_info "Cloning zstd repository (version v$ZSTD_VERSION)..."
    git clone "$ZSTD_REPO" "$ZSTD_SRC_DIR"

    cd "$ZSTD_SRC_DIR"
    # 检查标签是否存在
    if ! git rev-parse "v$ZSTD_VERSION" >/dev/null 2>&1; then
        print_error "Tag v$ZSTD_VERSION does not exist in the repository!"
        print_info "Available tags:"
        git tag -l | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | tail -10
        exit 1
    fi

    git checkout "v$ZSTD_VERSION"
    cd "$SCRIPT_DIR"
fi

# 验证 Zstd 源码目录结构
if [ ! -d "$ZSTD_SRC_DIR/build/cmake" ]; then
    print_error "Invalid Zstd source structure: Missing build/cmake directory in $ZSTD_SRC_DIR"
    exit 1
fi

print_info "--- Starting Zstd Android Build (Shared Lib .so) ---"
print_info "SCRIPT_DIR:    $SCRIPT_DIR"
print_info "NDK Root:      $NDK_ROOT"
print_info "Target API:    $API_LEVEL"
print_info "Target ABIs:   ${ABIS[*]}"
print_info "Zstd Version:  $ZSTD_VERSION"
print_info "Zstd Source:   $ZSTD_SRC_DIR"
print_info "Install Prefix: $PREFIX_DIR"
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
# 3. 交叉编译循环（按 ABI 逐个编译）
# ======================================================================

for ABI in "${ABIS[@]}"; do
    print_info "=========================================="
    print_info "Building Zstd for ABI: $ABI"
    print_info "=========================================="

    # 1. 为当前 ABI 创建构建和安装目录（使用绝对路径）
    ABI_BUILD_DIR="$BUILD_DIR/$ABI"
    ABI_PREFIX_DIR="$PREFIX_DIR/$ABI"
    mkdir -p "$ABI_BUILD_DIR"
    mkdir -p "$ABI_PREFIX_DIR"

    # 获取绝对路径（确保路径正确性）
    ABI_PREFIX_DIR_ABS="$(realpath "$ABI_PREFIX_DIR")"
    print_info "ABI Build Dir:   $ABI_BUILD_DIR"
    print_info "ABI Install Dir: $ABI_PREFIX_DIR_ABS"

    # 2. 执行 CMake 配置
    print_info "Running CMake configuration for $ABI..."
    cmake -S "$ZSTD_SRC_DIR/build/cmake" \
          -B "$ABI_BUILD_DIR" \
          -G "Ninja" \
          -DCMAKE_CXX_STANDARD=20 \
          -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" \
          -DANDROID_PLATFORM=android-"$API_LEVEL" \
          -DANDROID_ABI="$ABI" \
          -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX="$ABI_PREFIX_DIR_ABS" \
          -DZSTD_BUILD_PROGRAMS=OFF \
          -DZSTD_BUILD_SHARED=ON \
          -DZSTD_BUILD_STATIC=OFF \
          -DZSTD_BUILD_CONTRIB=OFF \
          -DZSTD_BUILD_TESTS=OFF \
          -DCMAKE_POSITION_INDEPENDENT_CODE=ON

    # 3. 执行编译和安装（使用多核编译加速）
    print_info "Building Zstd for $ABI (using multiple cores)..."
    cmake --build "$ABI_BUILD_DIR" --target install -j$(sysctl -n hw.ncpu 2>/dev/null || nproc)

    # 4. 验证安装结果（检查共享库是否存在）
    SO_FILE="$ABI_PREFIX_DIR_ABS/lib/libzstd.so"
    if [ ! -f "$SO_FILE" ]; then
        print_error "Build failed: libzstd.so not found for $ABI at $SO_FILE"
        exit 1
    fi

    # 额外验证：检查库文件是否为目标架构
    print_info "Verifying library architecture for $ABI..."
    file "$SO_FILE" | grep -q "$ABI" && print_info "Library architecture check passed" || print_warning "Library architecture may not match target ABI"

    print_success "Successfully built and installed Zstd for $ABI"
    echo  # 空行分隔，提升可读性
done

# ======================================================================
# 4. 结论
# ======================================================================
print_info "--------------------------------------------------------"
print_success "Zstd Android Build Completed Successfully for all target ABIs!"
print_info "Shared libraries (.so) are installed in: $PREFIX_DIR"
print_info "--------------------------------------------------------"

# 手动触发清理（trap 也会执行，但显式调用更清晰）
cleanup