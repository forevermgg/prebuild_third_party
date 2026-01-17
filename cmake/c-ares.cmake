# =============================================
# c-ares 库配置
# =============================================

# 设置 c-ares 库的根目录
set(CARES_ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/third_party/prefix/c-ares")

# 检查 Android ABI
if(NOT CMAKE_ANDROID_ARCH_ABI)
    message(FATAL_ERROR "未检测到 Android ABI (CMAKE_ANDROID_ARCH_ABI)，请在 Android 环境下构建")
endif()

# 设置 ABI 特定目录
set(CARES_ABI_DIR "${CARES_ROOT_DIR}/${CMAKE_ANDROID_ARCH_ABI}")

# 验证 c-ares 头文件和静态库文件是否存在
if(NOT EXISTS "${CARES_ABI_DIR}/include/ares.h")
    message(FATAL_ERROR "c-ares 头文件缺失: ${CARES_ABI_DIR}/include/ares.h")
endif()

if(NOT EXISTS "${CARES_ABI_DIR}/lib/libcares.a")
    message(FATAL_ERROR "c-ares 静态库缺失: ${CARES_ABI_DIR}/lib/libcares.a")
endif()

message("c-ares 路径: ${CARES_ABI_DIR}")

# 导入 c-ares 静态库
if(NOT TARGET cares_lib)
    add_library(cares_lib STATIC IMPORTED GLOBAL)

    # 设置导入库的属性：位置和头文件路径
    set_target_properties(cares_lib PROPERTIES
            IMPORTED_LOCATION ${CARES_ABI_DIR}/lib/libcares.so
            INTERFACE_INCLUDE_DIRECTORIES ${CARES_ABI_DIR}/include
            INTERFACE_COMPILE_DEFINITIONS CARES_STATICLIB  # 静态库编译定义
    )

    # 获取版本信息（从 ares_version.h 中提取）
    if(EXISTS "${CARES_ABI_DIR}/include/ares_version.h")
        file(STRINGS "${CARES_ABI_DIR}/include/ares_version.h" CARES_VERSION_MAJOR_LINE REGEX "^#define ARES_VERSION_MAJOR +[0-9]+")
        file(STRINGS "${CARES_ABI_DIR}/include/ares_version.h" CARES_VERSION_MINOR_LINE REGEX "^#define ARES_VERSION_MINOR +[0-9]+")
        file(STRINGS "${CARES_ABI_DIR}/include/ares_version.h" CARES_VERSION_PATCH_LINE REGEX "^#define ARES_VERSION_PATCH +[0-9]+")

        string(REGEX REPLACE "^#define ARES_VERSION_MAJOR +([0-9]+)" "\\1" CARES_VERSION_MAJOR "${CARES_VERSION_MAJOR_LINE}")
        string(REGEX REPLACE "^#define ARES_VERSION_MINOR +([0-9]+)" "\\1" CARES_VERSION_MINOR "${CARES_VERSION_MINOR_LINE}")
        string(REGEX REPLACE "^#define ARES_VERSION_PATCH +([0-9]+)" "\\1" CARES_VERSION_PATCH "${CARES_VERSION_PATCH_LINE}")

        set(CARES_VERSION "${CARES_VERSION_MAJOR}.${CARES_VERSION_MINOR}.${CARES_VERSION_PATCH}")
        set_target_properties(cares_lib PROPERTIES
                VERSION ${CARES_VERSION}
                SOVERSION ${CARES_VERSION_MAJOR}
        )
        message(STATUS "c-ares 版本: ${CARES_VERSION}")
    endif()

    # 添加链接依赖（Android 平台可能需要的系统库）
    set_target_properties(cares_lib PROPERTIES
            INTERFACE_LINK_LIBRARIES "dl;m;log"
    )
endif()

# 提供查找包兼容性
set(CARES_FOUND TRUE)
set(CARES_INCLUDE_DIRS ${CARES_ABI_DIR}/include)
set(CARES_LIBRARIES cares_lib)
set(CARES_VERSION ${CARES_VERSION})

# 打印配置摘要
message(STATUS "c-ares 配置完成:")
message(STATUS "  - 头文件目录: ${CARES_ABI_DIR}/include")
message(STATUS "  - 库文件: ${CARES_ABI_DIR}/lib/libcares.a")
message(STATUS "  - 目标名称: cares_lib")
message(STATUS "  - 版本: ${CARES_VERSION}")