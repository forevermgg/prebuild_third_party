# =============================================
# Zstd (Zstandard) 库配置
# =============================================

# 设置 Zstd 库的根目录
set(ZSTD_ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/third_party/prefix/zstd")

# 检查 Android ABI
if(NOT CMAKE_ANDROID_ARCH_ABI)
    message(FATAL_ERROR "未检测到 Android ABI (CMAKE_ANDROID_ARCH_ABI)，请在 Android 环境下构建")
endif()

# 设置 ABI 特定目录
set(ZSTD_ABI_DIR "${ZSTD_ROOT_DIR}/${CMAKE_ANDROID_ARCH_ABI}")

# 验证 Zstd 头文件和共享库文件是否存在
if(NOT EXISTS "${ZSTD_ABI_DIR}/include/zstd.h")
    message(FATAL_ERROR "Zstd 头文件缺失: ${ZSTD_ABI_DIR}/include/zstd.h")
endif()

if(NOT EXISTS "${ZSTD_ABI_DIR}/lib/libzstd.so")
    message(FATAL_ERROR "Zstd 共享库缺失: ${ZSTD_ABI_DIR}/lib/libzstd.so")
endif()

message(STATUS "Zstd 路径: ${ZSTD_ABI_DIR}")

# 导入 Zstd 共享库
if(NOT TARGET zstd_lib)
    add_library(zstd_lib SHARED IMPORTED GLOBAL)

    # 设置导入库的属性：位置和头文件路径
    set_target_properties(zstd_lib PROPERTIES
            IMPORTED_LOCATION ${ZSTD_ABI_DIR}/lib/libzstd.so
            INTERFACE_INCLUDE_DIRECTORIES ${ZSTD_ABI_DIR}/include
    )

    # 添加版本信息（可选）
    if(EXISTS "${ZSTD_ABI_DIR}/include/zstd.h")
        file(STRINGS "${ZSTD_ABI_DIR}/include/zstd.h" ZSTD_VERSION_MAJOR_LINE REGEX "^#define ZSTD_VERSION_MAJOR +[0-9]+")
        file(STRINGS "${ZSTD_ABI_DIR}/include/zstd.h" ZSTD_VERSION_MINOR_LINE REGEX "^#define ZSTD_VERSION_MINOR +[0-9]+")
        file(STRINGS "${ZSTD_ABI_DIR}/include/zstd.h" ZSTD_VERSION_RELEASE_LINE REGEX "^#define ZSTD_VERSION_RELEASE +[0-9]+")

        string(REGEX REPLACE "^#define ZSTD_VERSION_MAJOR +([0-9]+)" "\\1" ZSTD_VERSION_MAJOR "${ZSTD_VERSION_MAJOR_LINE}")
        string(REGEX REPLACE "^#define ZSTD_VERSION_MINOR +([0-9]+)" "\\1" ZSTD_VERSION_MINOR "${ZSTD_VERSION_MINOR_LINE}")
        string(REGEX REPLACE "^#define ZSTD_VERSION_RELEASE +([0-9]+)" "\\1" ZSTD_VERSION_RELEASE "${ZSTD_VERSION_RELEASE_LINE}")

        set(ZSTD_VERSION "${ZSTD_VERSION_MAJOR}.${ZSTD_VERSION_MINOR}.${ZSTD_VERSION_RELEASE}")
        set_target_properties(zstd_lib PROPERTIES
                VERSION ${ZSTD_VERSION}
                SOVERSION ${ZSTD_VERSION_MAJOR}
        )
        message(STATUS "Zstd 版本: ${ZSTD_VERSION}")
    endif()
endif()

# 提供查找包兼容性（可选）
set(ZSTD_FOUND TRUE)
set(ZSTD_INCLUDE_DIRS ${ZSTD_ABI_DIR}/include)
set(ZSTD_LIBRARIES zstd_lib)

# 打印配置摘要
message(STATUS "Zstd 配置完成:")
message(STATUS "  - 头文件目录: ${ZSTD_ABI_DIR}/include")
message(STATUS "  - 库文件: ${ZSTD_ABI_DIR}/lib/libzstd.so")
message(STATUS "  - 目标名称: zstd_lib")