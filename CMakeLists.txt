cmake_minimum_required(VERSION 3.30.3)
project("forever")

# =============================================
# 1. 环境检查与 NDK/LLVM 配置
# =============================================
if(NOT ANDROID_NDK_HOME)
 message(FATAL_ERROR "ANDROID_NDK_HOME is not set!")
endif()

file(TO_CMAKE_PATH "${ANDROID_NDK_HOME}" NDK_PATH)

# 自动识别 Host 平台
set(HOST_TAG "linux-x86_64")
if(APPLE)
 set(HOST_TAG "darwin-x86_64")
elseif(WIN32)
 set(HOST_TAG "windows-x86_64")
endif()

set(NDK_LLVM_DIR "${NDK_PATH}/toolchains/llvm/prebuilt/${HOST_TAG}")
set(LLVM_INCLUDE_DIRS "${NDK_LLVM_DIR}/include")

# 探测 Lib 目录 (NDK 27+ 常见 lib64)
set(LLVM_LIB_DIR_SEARCH "${NDK_LLVM_DIR}/lib64" "${NDK_LLVM_DIR}/lib")
foreach(path ${LLVM_LIB_DIR_SEARCH})
 if(IS_DIRECTORY "${path}")
  set(LLVM_LIB_DIRS "${path}")
  break()
 endif()
endforeach()

set(LLVM_DIR "${LLVM_LIB_DIRS}/cmake/llvm")
message("LLVM_DIR: ${LLVM_DIR}")
message("NDK_PATH: ${NDK_PATH}")
message("NDK_LLVM_DIR: ${NDK_LLVM_DIR}")
message("LLVM_INCLUDE_DIRS: ${LLVM_INCLUDE_DIRS}")
message("LLVM_LIB_DIRS: ${LLVM_LIB_DIRS}")
# /Users/centforever/Library/Android/sdk/ndk/25.1.8937393/toolchains/llvm/prebuilt/darwin-x86_64/
# /Users/centforever/Library/Android/sdk/ndk/29.0.14206865/toolchains/llvm/prebuilt/darwin-x86_64/bin/clang --version
# /Users/centforever/Library/Android/sdk/ndk/29.0.14206865/toolchains/llvm/prebuilt/darwin-x86_64/lib64/cmake/llvm
# defines['LLVM_ENABLE_PLUGINS'] = 'OFF'
# https://android.googlesource.com/toolchain/llvm_android/+/b497d21a7784e3af5066b3e7c259df0d155226fc%5E%21

# =============================================
# 2. 基础配置与依赖包含
# =============================================
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
include(cmake/BaseConfig.cmake)
include(Compiler.cmake)
include(cmake/QciBuild.cmake)
include(cmake/Dir.cmake)

# =============================================
# 第三方库配置
# =============================================
include(cmake/Zstd.cmake)
include(cmake/c-ares.cmake)
include(cmake/libuv.cmake)
include(cmake/fmt.cmake)
include(cmake/OpenSSL.cmake)

# OpenSSL配置
set(OPENSSL_INCLUDE_DIR ${OPENSSL_ABI_DIR}/include CACHE PATH "" FORCE)
set(OPENSSL_SSL_LIBRARY ${OPENSSL_ABI_DIR}/lib/libssl.so CACHE FILEPATH "" FORCE)
set(OPENSSL_CRYPTO_LIBRARY ${OPENSSL_ABI_DIR}/lib/libcrypto.so CACHE FILEPATH "" FORCE)
set(OPENSSL_FOUND TRUE CACHE BOOL "" FORCE)

# 关键修复：强制设置Poco输出目录[6,8](@ref)
# 必须在add_subdirectory之前设置这些变量
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_LIBRARY_OUTPUT_DIRECTORY} CACHE PATH "Library output directory" FORCE)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_LIBRARY_OUTPUT_DIRECTORY} CACHE PATH "Archive output directory" FORCE)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_LIBRARY_OUTPUT_DIRECTORY} CACHE PATH "Runtime output directory" FORCE)

# 设置特定于构建类型的输出目录
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_${CMAKE_BUILD_TYPE} ${CMAKE_LIBRARY_OUTPUT_DIRECTORY} CACHE PATH "" FORCE)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY_${CMAKE_BUILD_TYPE} ${CMAKE_LIBRARY_OUTPUT_DIRECTORY} CACHE PATH "" FORCE)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_${CMAKE_BUILD_TYPE} ${CMAKE_LIBRARY_OUTPUT_DIRECTORY} CACHE PATH "" FORCE)

# =============================================
# 3. 创建主项目 libforever.so（修改：移除fml相关代码，添加fml库依赖）
# =============================================
# 收集主项目源文件（已移除fml模块代码）
set(FOREVER_SRCS
        # 项目业务代码
        build_project/Android/base/src/main/cpp/base.cpp
)

# 创建主项目库
add_library(${CMAKE_PROJECT_NAME} SHARED ${FOREVER_SRCS})

# 设置主项目编译选项
target_compile_options(${CMAKE_PROJECT_NAME} PRIVATE -fexceptions)

# 主项目头文件包含路径
# 使用 target_include_directories 的现代用法
target_include_directories(${CMAKE_PROJECT_NAME}
        PRIVATE
        ${OPENSSL_ABI_DIR}/include
        PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
)

# 定义所有版本都需要链接的公共依赖库（新增：添加fml库依赖）
set(COMMON_LIBS
        fmt
        zstd_lib
        cares_lib
        openssl_ssl
        openssl_crypto
        uv
        android
        log
)

# 根据API级别条件添加permission_manager
if (CMAKE_ANDROID_API_LEVEL GREATER_EQUAL 31)
 # 高版本：公共库 + permission_manager
 target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE
         ${COMMON_LIBS}
         permission_manager
 )
else()
 # 低版本：仅公共库
 target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE
         ${COMMON_LIBS}
 )
endif()