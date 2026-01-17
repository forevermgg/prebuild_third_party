# =============================================
# libuv 库配置 - 本地查找版本
# =============================================
# 修改项: 新增 libuv 本地查找配置

# 设置 libuv 库的根目录
set(LIBUV_ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/third_party/prefix/libuv")

# 检查 Android ABI
if(NOT CMAKE_ANDROID_ARCH_ABI)
    message(WARNING "未检测到 Android ABI，跳过 libuv 配置")
    return()
endif()

# 设置 ABI 特定目录
set(LIBUV_ABI_DIR "${LIBUV_ROOT_DIR}/${CMAKE_ANDROID_ARCH_ABI}")

# 验证 libuv 头文件和共享库文件是否存在
if(NOT EXISTS "${LIBUV_ABI_DIR}/include/uv.h")
    message(WARNING "libuv 头文件缺失: ${LIBUV_ABI_DIR}/include/uv.h")
    return()
endif()

if(NOT EXISTS "${LIBUV_ABI_DIR}/lib/libuv.so")
    message(WARNING "libuv 共享库缺失: ${LIBUV_ABI_DIR}/lib/libuv.so")
    return()
endif()

message(STATUS "libuv 路径: ${LIBUV_ABI_DIR}")

# 导入 libuv 共享库
if(NOT TARGET uv)
    add_library(uv SHARED IMPORTED GLOBAL)

    set_target_properties(uv PROPERTIES
            IMPORTED_LOCATION ${LIBUV_ABI_DIR}/lib/libuv.so
            INTERFACE_INCLUDE_DIRECTORIES ${LIBUV_ABI_DIR}/include
    )

    # 添加版本信息（可选）
    if(EXISTS "${LIBUV_ABI_DIR}/include/uv/version.h")
        file(STRINGS "${LIBUV_ABI_DIR}/include/uv/version.h" LIBUV_VERSION_MAJOR_LINE REGEX "^#define UV_VERSION_MAJOR +[0-9]+")
        file(STRINGS "${LIBUV_ABI_DIR}/include/uv/version.h" LIBUV_VERSION_MINOR_LINE REGEX "^#define UV_VERSION_MINOR +[0-9]+")
        file(STRINGS "${LIBUV_ABI_DIR}/include/uv/version.h" LIBUV_VERSION_PATCH_LINE REGEX "^#define UV_VERSION_PATCH +[0-9]+")

        string(REGEX REPLACE "^#define UV_VERSION_MAJOR +([0-9]+)" "\\1" LIBUV_VERSION_MAJOR "${LIBUV_VERSION_MAJOR_LINE}")
        string(REGEX REPLACE "^#define UV_VERSION_MINOR +([0-9]+)" "\\1" LIBUV_VERSION_MINOR "${LIBUV_VERSION_MINOR_LINE}")
        string(REGEX REPLACE "^#define UV_VERSION_PATCH +([0-9]+)" "\\1" LIBUV_VERSION_PATCH "${LIBUV_VERSION_PATCH_LINE}")

        set(LIBUV_VERSION "${LIBUV_VERSION_MAJOR}.${LIBUV_VERSION_MINOR}.${LIBUV_VERSION_PATCH}")
        set_target_properties(uv PROPERTIES
                VERSION ${LIBUV_VERSION}
                SOVERSION ${LIBUV_VERSION_MAJOR}
        )
        message(STATUS "libuv 版本: ${LIBUV_VERSION}")
    endif()

    message(STATUS "libuv 配置完成: ${LIBUV_ABI_DIR}")
endif()

# 提供查找包兼容性
set(libuv_FOUND TRUE)
set(libuv_INCLUDE_DIRS ${LIBUV_ABI_DIR}/include)
set(libuv_LIBRARIES uv)