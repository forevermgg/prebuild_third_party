# =============================================
# fmt 库配置 - 本地查找版本
# =============================================
# 修改项: 新增 fmt 本地查找配置

# 设置 fmt 库的根目录
set(FMT_ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/third_party/prefix/fmt")

# 检查 Android ABI
if(NOT CMAKE_ANDROID_ARCH_ABI)
    message(WARNING "未检测到 Android ABI，跳过 fmt 配置")
    return()
endif()

# 设置 ABI 特定目录
set(FMT_ABI_DIR "${FMT_ROOT_DIR}/${CMAKE_ANDROID_ARCH_ABI}")

# 验证 fmt 头文件和共享库文件是否存在
if(NOT EXISTS "${FMT_ABI_DIR}/include/fmt/format.h")
    message(WARNING "fmt 头文件缺失: ${FMT_ABI_DIR}/include/fmt/format.h")
    return()
endif()

if(NOT EXISTS "${FMT_ABI_DIR}/lib/libfmt.so")
    message(WARNING "fmt 共享库缺失: ${FMT_ABI_DIR}/lib/libfmt.so")
    return()
endif()

message(STATUS "fmt 路径: ${FMT_ABI_DIR}")

# 导入 fmt 共享库
if(NOT TARGET fmt)
    add_library(fmt SHARED IMPORTED GLOBAL)

    set_target_properties(fmt PROPERTIES
            IMPORTED_LOCATION ${FMT_ABI_DIR}/lib/libfmt.so
            INTERFACE_INCLUDE_DIRECTORIES ${FMT_ABI_DIR}/include
    )

    # 添加版本信息（可选）
    if(EXISTS "${FMT_ABI_DIR}/include/fmt/format.h")
        file(STRINGS "${FMT_ABI_DIR}/include/fmt/format.h" FMT_VERSION_LINE REGEX "^#define FMT_VERSION +[0-9]+")
        string(REGEX REPLACE "^#define FMT_VERSION +([0-9]+)" "\\1" FMT_VERSION_NUM "${FMT_VERSION_LINE}")

        if(FMT_VERSION_NUM)
            # 将版本号转换为 x.y.z 格式
            math(EXPR FMT_VERSION_MAJOR "${FMT_VERSION_NUM} / 10000")
            math(EXPR FMT_VERSION_MINOR "(${FMT_VERSION_NUM} % 10000) / 100")
            math(EXPR FMT_VERSION_PATCH "${FMT_VERSION_NUM} % 100")
            set(FMT_VERSION "${FMT_VERSION_MAJOR}.${FMT_VERSION_MINOR}.${FMT_VERSION_PATCH}")

            set_target_properties(fmt PROPERTIES
                    VERSION ${FMT_VERSION}
                    SOVERSION ${FMT_VERSION_MAJOR}
            )
            message(STATUS "fmt 版本: ${FMT_VERSION}")
        endif()
    endif()

    message(STATUS "fmt 配置完成: ${FMT_ABI_DIR}")
endif()

# 提供查找包兼容性
set(fmt_FOUND TRUE)
set(fmt_INCLUDE_DIRS ${FMT_ABI_DIR}/include)
set(fmt_LIBRARIES fmt)