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

# 源代码和目标目录
readonly LIBUV_REPO_URL="https://github.com/libuv/libuv.git"
readonly LIBUV_SRC_DIR="libuv"
readonly PREFIX_DIR="./prefix/libuv"
readonly BUILD_DIR="build_libuv_android"

# NDK CMake 工具链文件路径
readonly TOOLCHAIN_FILE="$NDK_ROOT/build/cmake/android.toolchain.cmake"

# 将逗号分隔的 ABI 字符串转换为 Bash 数组
IFS=',' read -r -a ABIS <<< "$TARGET_ABIS_STR"

# ======================================================================
# 2. 准备源码
# ======================================================================

# 克隆或更新源码
if [ ! -d "$LIBUV_SRC_DIR" ]; then
    print_info "Cloning libuv repository..."
    git clone --depth 1 --branch v1.51.0 "$LIBUV_REPO_URL" "$LIBUV_SRC_DIR"
else
    print_info "Updating existing libuv repository..."
    git -C "$LIBUV_SRC_DIR" fetch origin v1.51.0
    git -C "$LIBUV_SRC_DIR" checkout v1.51.0
fi

# 检查关键文件和目录
if [ ! -f "$TOOLCHAIN_FILE" ]; then
    print_error "NDK Toolchain file not found at: $TOOLCHAIN_FILE"
    exit 1
fi
if [ ! -f "$LIBUV_SRC_DIR/CMakeLists.txt" ]; then
    print_error "libuv source directory '$LIBUV_SRC_DIR' is invalid"
    exit 1
fi

print_info "--- Starting libuv Android Build (Shared Lib .so) ---"
print_info "NDK Root: $NDK_ROOT"
print_info "Target API Level: $API_LEVEL"
print_info "Target ABIs: ${ABIS[*]}"
print_info "-----------------------------------"

# 清理构建目录
print_info "Cleaning up previous build directory: $BUILD_DIR"
rm -rf "$BUILD_DIR"
# 清理安装目录
print_info "Cleaning up installation directory: $PREFIX_DIR"
rm -rf "$PREFIX_DIR"

# ======================================================================
# 3. 交叉编译循环
# ======================================================================

for ABI in "${ABIS[@]}"; do
    print_info "=========================================="
    print_info "Building libuv for ABI: $ABI"
    print_info "=========================================="

    # 创建 ABI 专属构建目录
    readonly ABI_BUILD_DIR="$BUILD_DIR/$ABI"
    mkdir -p "$ABI_BUILD_DIR"

    # 执行 CMake 配置
    print_info "Running CMake configuration..."
    cmake -S "$LIBUV_SRC_DIR" \
          -B "$ABI_BUILD_DIR" \
          -G "Ninja" \
          -DCMAKE_C_STANDARD=11 \
          -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" \
          -DANDROID_PLATFORM=android-"$API_LEVEL" \
          -DANDROID_ABI="$ABI" \
          -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX="$PREFIX_DIR/$ABI" \
          -DLIBUV_BUILD_TESTS=OFF \
          -DBUILD_SHARED_LIBS=ON \
          -DCMAKE_POSITION_INDEPENDENT_CODE=ON

    # 执行编译和安装
    print_info "Building and installing libuv..."
    cmake --build "$ABI_BUILD_DIR" --target install

    # 验证安装结果
    if [ ! -f "$PREFIX_DIR/$ABI/lib/libuv.so" ]; then
        print_error "Build failed: libuv.so not found for $ABI at $PREFIX_DIR/$ABI/lib/"
        exit 1
    fi

    print_success "Successfully built and installed libuv for $ABI"
done

# ======================================================================
# 4. 创建聚合头文件（可选）
# ======================================================================

print_info "Creating unified include directory..."
mkdir -p "$PREFIX_DIR/include"
cp -r "$PREFIX_DIR/${ABIS[0]}/include/"* "$PREFIX_DIR/include/"

# ======================================================================
# 5. 结论
# ======================================================================

print_info "--------------------------------------------------------"
print_success "libuv Android Build Completed Successfully for all target ABIs!"
print_info "Shared libraries (.so) are installed in: $PREFIX_DIR"
print_info "Include headers are in: $PREFIX_DIR/include"
print_info "--------------------------------------------------------"