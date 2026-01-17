# =============================================
# OpenSSL 库配置
# =============================================
# 修改项: 将 OpenSSL 配置提取到单独文件

set(OPENSSL_ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/third_party/prefix/openssl")

# 检查 Android ABI
if(NOT CMAKE_ANDROID_ARCH_ABI)
    message(FATAL_ERROR "未检测到 Android ABI，请在 Android 环境下构建")
endif()

set(OPENSSL_ABI_DIR "${OPENSSL_ROOT_DIR}/${CMAKE_ANDROID_ARCH_ABI}")

# 验证OpenSSL文件
if(NOT EXISTS "${OPENSSL_ABI_DIR}/include/openssl/ssl.h")
    message(FATAL_ERROR "OpenSSL 头文件缺失: ${OPENSSL_ABI_DIR}/include/openssl/ssl.h")
endif()

if(NOT EXISTS "${OPENSSL_ABI_DIR}/lib/libssl.so" OR NOT EXISTS "${OPENSSL_ABI_DIR}/lib/libcrypto.so")
    message(FATAL_ERROR "OpenSSL 库文件缺失: ${OPENSSL_ABI_DIR}/lib/")
endif()

message(STATUS "OpenSSL 路径: ${OPENSSL_ABI_DIR}")

# 导入OpenSSL库
if(NOT TARGET openssl_ssl)
    add_library(openssl_ssl SHARED IMPORTED GLOBAL)
    set_target_properties(openssl_ssl PROPERTIES
            IMPORTED_LOCATION ${OPENSSL_ABI_DIR}/lib/libssl.so
            INTERFACE_INCLUDE_DIRECTORIES ${OPENSSL_ABI_DIR}/include
    )
endif()

if(NOT TARGET openssl_crypto)
    add_library(openssl_crypto SHARED IMPORTED GLOBAL)
    set_target_properties(openssl_crypto PROPERTIES
            IMPORTED_LOCATION ${OPENSSL_ABI_DIR}/lib/libcrypto.so
            INTERFACE_INCLUDE_DIRECTORIES ${OPENSSL_ABI_DIR}/include
    )
endif()

# 创建 Poco 期望的目标名称
if(NOT TARGET OpenSSL::SSL)
    add_library(OpenSSL::SSL UNKNOWN IMPORTED)
    set_target_properties(OpenSSL::SSL PROPERTIES
            IMPORTED_LOCATION ${OPENSSL_ABI_DIR}/lib/libssl.so
            INTERFACE_INCLUDE_DIRECTORIES ${OPENSSL_ABI_DIR}/include
    )
endif()

if(NOT TARGET OpenSSL::Crypto)
    add_library(OpenSSL::Crypto UNKNOWN IMPORTED)
    set_target_properties(OpenSSL::Crypto PROPERTIES
            IMPORTED_LOCATION ${OPENSSL_ABI_DIR}/lib/libcrypto.so
            INTERFACE_INCLUDE_DIRECTORIES ${OPENSSL_ABI_DIR}/include
    )
endif()

# 提供查找包兼容性
set(OPENSSL_FOUND TRUE)
set(OPENSSL_INCLUDE_DIR ${OPENSSL_ABI_DIR}/include)
set(OPENSSL_SSL_LIBRARY openssl_ssl)
set(OPENSSL_CRYPTO_LIBRARY openssl_crypto)
set(OPENSSL_LIBRARIES ${OPENSSL_SSL_LIBRARY} ${OPENSSL_CRYPTO_LIBRARY})

message(STATUS "OpenSSL 配置完成")