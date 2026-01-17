#!/bin/bash
set -u
set -euo pipefail  # 增强错误检测，避免未定义变量和管道失败忽略

# 脚本配置
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 颜色输出函数
print_info() { echo -e "\033[1;34m[INFO] $*\033[0m"; }
print_success() { echo -e "\033[1;32m[SUCCESS] $*\033[0m"; }
print_warning() { echo -e "\033[1;33m[WARNING] $*\033[0m"; }
print_error() { echo -e "\033[1;31m[ERROR] $*\033[0m" >&2; }

# 配置参数（可按需修改）
export OPENSSL_BRANCH=openssl-3.6.0
export OPENSSL_ANDROID_API=24  # 与NDK兼容的API级别

# 获取NDK路径（参数优先，环境变量次之）
NDK=${1:-${NDK:-""}}
if [ -z "$NDK" ]; then
    print_error "NDK路径未设置置，请提供NDK路径作为脚本参数，或设置NDK环境变量"
    exit 1
fi

# 验证NDK路径有效性
if [ ! -d "$NDK" ] || [ ! -f "$NDK/source.properties" ]; then
    print_error "无效的NDK路径：$NDK（缺少source.properties文件）"
    exit 1
fi

export ANDROID_NDK_HOME=$NDK
export ANDROID_NDK_ROOT=$NDK

# 构建输出路径配置
export BASE=$(realpath "${BASE:-$(pwd)}")
export PREFIX=$BASE/prefix/openssl

# 处理已存在的输出目录（**自动删除并重建**）
if [ -d "$PREFIX" ]; then
    print_warning "目标目录已存在，自动删除并重建：$PREFIX"
    rm -rf "$PREFIX" || { print_error "删除目录失败：$PREFIX"; exit 1; }
fi
mkdir -p "$PREFIX" || { print_error "创建输出目录失败：$PREFIX"; exit 1; }

# 克隆/更新OpenSSL源码（针对标签处理）
cd "$BASE" || { print_error "切换目录失败：$BASE"; exit 1; }
if [ ! -d "openssl" ]; then
    print_info "克隆OpenSSL源码（标签：$OPENSSL_BRANCH）"
    # 克隆仓库并检出检出指定标签（--branch 可同时支持分支和标签）
    git clone --branch "$OPENSSL_BRANCH" git://git.openssl.org/openssl.git || {
        print_error "克隆失败，尝试HTTPS源..."
        git clone clone --branch "$OPENSSL_BRANCH" https://git.openssl.org/openssl.git || {
            print_error "HTTPS克隆也失败，请检查网络连接"
            exit 1
        }
    }
else
    print_info "更新OpenSSL源码到标签：$OPENSSL_BRANCH"
    cd openssl || exit 1
    # 拉取最新的标签信息（关键：标签需要单独拉取）
    git fetch --tags origin || { print_error "拉取远程标签失败"; exit 1; }
    # 检出指定标签（标签不需要origin/前缀）
    git checkout "$OPENSSL_BRANCH" || { print_error "检出标签失败"; exit 1; }
fi
print_info "当前目录为 $(pwd)"
cd  ../
cd openssl || { print_error "切换到OpenSSL目录失败"; exit 1; }  # 修复冗余cd ../

# 验证Configure脚本可用性
if [ ! -f "Configure" ]; then
    print_error "未找到Configure脚本，源码目录异常"
    exit 1
fi
if ! perl Configure LIST | grep -q "android-" >/dev/null 2>&1; then
    print_error "当前OpenSSL版本不支持Android配置，请确认标签：$OPENSSL_BRANCH"
    exit 1
fi

print_info "OpenSSL构建目录：$(realpath "$PWD")"
print_info "输出目录：$PREFIX"

# 配置NDK工具链（修复macOS路径判断）
HOST_OS=$(uname -s | tr '[:upper:]' '[:lower:]')
HOST_ARCH=$(uname -m)

# 关键修复：NDK在macOS上无论主机架构如何，工具链目录均为darwin-x86_64
if [ "$HOST_OS" = "darwin" ]; then
    TOOLCHAIN_ARCH="x86_64"  # macOS强制使用x86_64工具链目录
elif [ "$HOST_ARCH" = "x86_64" ]; then
    TOOLCHAIN_ARCH="x86_64"
else
    print_error "不支持的主机架构：$HOST_ARCH（操作系统：$HOST_OS）"
    exit 1
fi

TOOLCHAIN_PATH="$NDK/toolchains/llvm/prebuilt/${HOST_OS}-${TOOLCHAIN_ARCH}"

# 验证工具链有效性
if [ ! -d "$TOOLCHAIN_PATH" ] || [ ! -f "$TOOLCHAIN_PATH/bin/clang" ]; then
    print_error "NDK工具链不存在或不完整：$TOOLCHAIN_PATH"
    print_error "请检查NDK版本（推荐r22+）"
    exit 1
fi
export PATH="$TOOLCHAIN_PATH/bin:$PATH"
print_info "工具链路径：$TOOLCHAIN_PATH"

# 构建函数（修复参数传递和配置逻辑）
function build_OpenSSL {
    local abi="$1"
    local api_level="$2"
    local target=""
    local extra_cflags=""

    # ABI与目标架构映射（匹配OpenSSL配置）
    case "$abi" in
        armeabi-v7a)
            target="android-arm"
            extra_cflags="-march=armv7-a -mfpu=neon"  # 启用NEON优化
            ;;
        arm64-v8a)
            target="android-arm64"
            extra_cflags="-march=armv8-a"
            ;;
        x86)
            target="android-x86"
            extra_cflags="-march=i686 -mssse3 -mfpmath=sse"
            ;;
        x86_64)
            target="android-x86_64"
            extra_cflags="-march=x86-64 -msse4.2 -mpopcnt -mtune=x86-64"
            ;;
        *)
            print_error "不支持的ABI：$abi"
            return 1
            ;;
    esac

    print_info "开始构建 ABI: $abi (目标架构: $target, API级别: $api_level)"
    local install_dir="$PREFIX/$abi"
    mkdir -p "$install_dir" || { print_error "创建安装目录失败：$install_dir"; return 1; }

    # 彻底清理之前的构建产物（避免残留影响）
    print_info "清理历史构建产物..."
    make distclean >/dev/null 2>&1 || true
    rm -rf "$install_dir" || { print_error "清理安装目录失败：$install_dir"; return 1; }

    # 核心配置命令（构建动态库）
    print_info "运行配置：perl Configure $target -D__ANDROID_API__=$api_level --prefix=$install_dir $extra_cflags shared"
    perl Configure \
        "$target" \
        -D__ANDROID_API__="$api_level" \
        --prefix="$install_dir" \
        "$extra_cflags" \
        shared  # 构建动态库

    # 验证Makefile生成
    if [ ! -f "Makefile" ]; then
        print_error "配置未生成Makefile（ABI: $abi）"
        return 1
    fi

    # 编译和安装（指定-j参数优化并行编译）
    local jobs=$(nproc 2>/dev/null || echo 4)  # 兼容macOS（nproc替换为sysctl）
    if [ "$HOST_OS" = "darwin" ]; then
        jobs=$(sysctl -n hw.ncpu)
    fi

    print_info "开始编译..."
    if ! make depend -j"$jobs"; then
        print_error "make depend失败（ABI: $abi）"
        return 1
    fi
    if ! make -j"$jobs" build_libs; then
        print_error "编译库失败（ABI: $abi）"
        return 1
    fi
    if ! make install_sw; then  # install_sw仅安装库和头文件，不安装文档
        print_error "安装失败（ABI: $abi）"
        return 1
    fi

    print_success "ABI: $abi 构建完成，输出目录：$install_dir"
    return 0
}

# 强制指定Clang工具链（避免系统默认编译器冲突）
export CC=clang
export CXX=clang++
export AR=llvm-ar
export RANLIB=llvm-ranlib
export STRIP=llvm-strip

# 构建所有支持的ABI
build_OpenSSL armeabi-v7a "$OPENSSL_ANDROID_API" || exit 1
build_OpenSSL arm64-v8a "$OPENSSL_ANDROID_API" || exit 1
build_OpenSSL x86 "$OPENSSL_ANDROID_API" || exit 1
build_OpenSSL x86_64 "$OPENSSL_ANDROID_API" || exit 1

print_success "所有ABI构建完成！最终输出目录：$PREFIX"