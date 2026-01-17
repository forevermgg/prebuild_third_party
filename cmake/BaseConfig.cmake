# =============================================
# 基础配置设置
# =============================================
# 修改项: 将基础配置提取到单独文件

# 设置C++标准
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 设置输出目录
if(ANDROID_ABI)
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/output/Android/${ANDROID_ABI})
else()
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/output/${CMAKE_SYSTEM_NAME})
endif()

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_LIBRARY_OUTPUT_DIRECTORY})
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_LIBRARY_OUTPUT_DIRECTORY})

# 编译器扩展和PIC设置
if(NOT CYGWIN AND NOT MSYS AND NOT ${CMAKE_SYSTEM_NAME} STREQUAL QNX)
    set(CMAKE_CXX_EXTENSIONS OFF)
endif()
set(CMAKE_POSITION_INDEPENDENT_CODE TRUE)

# 检查系统名称
if("${CMAKE_SYSTEM_NAME}" STREQUAL "")
    message(FATAL_ERROR "CMAKE_SYSTEM_NAME 未设置，无法确定系统类型")
endif()

# 构建类型配置
if(NOT CMAKE_BUILD_TYPE)
    message(STATUS "未指定构建类型，默认使用 RelWithDebInfo")
    set(CMAKE_BUILD_TYPE "RelWithDebInfo" CACHE STRING
            "构建类型选项: Debug Release RelWithDebInfo MinSizeRel" FORCE)
endif()

# 设置默认构建类型
if(NOT CMAKE_BUILD_TYPE)
    message(STATUS "Setting build type to 'RelWithDebInfo' as none was specified.")
    set(CMAKE_BUILD_TYPE "RelWithDebInfo" CACHE STRING
            "Choose the type of build, options are: Debug Release RelWithDebInfo MinSizeRel."
            FORCE)
endif()

# 编译器配置
message(STATUS "编译器: ${CMAKE_CXX_COMPILER_ID}")

# 使用现代的目标特定编译选项替代全局设置
if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    # 移除了全局CMAKE_CXX_FLAGS设置，将在目标级别设置
endif()

# 处理C++20兼容性警告
if(CMAKE_CXX_COMPILER_ID MATCHES "Clang|AppleClang|GNU")
    add_compile_options(-Wno-c++20-compat)
endif()

# 平台检测
if(ANDROID)
    set(IS_ANDROID TRUE)
    message(STATUS "构建平台: Android")
    message(STATUS "Android ABI: ${ANDROID_ABI}")
    message(STATUS "Android API 级别: ${ANDROID_PLATFORM}")
elseif(APPLE)
    set(IS_APPLE TRUE)
    message(STATUS "构建平台: Apple")
elseif(UNIX AND NOT APPLE)
    set(IS_LINUX TRUE)
    message(STATUS "构建平台: Linux")
elseif(WIN32)
    set(IS_WINDOWS TRUE)
    message(STATUS "构建平台: Windows")
else()
    message(STATUS "构建平台: ${CMAKE_SYSTEM_NAME}")
endif()

# 设置平台特定源文件目录名
if(IS_ANDROID)
    set(PLATFORM_SPECIFIC_SRC_DIR_NAME "unix")
elseif(IS_APPLE)
    set(PLATFORM_SPECIFIC_SRC_DIR_NAME "darwin")
elseif(IS_LINUX)
    set(PLATFORM_SPECIFIC_SRC_DIR_NAME "unix")
elseif(IS_WINDOWS)
    set(PLATFORM_SPECIFIC_SRC_DIR_NAME "win32")
else()
    set(PLATFORM_SPECIFIC_SRC_DIR_NAME "generic")
endif()

message(STATUS "平台特定源文件目录: ${PLATFORM_SPECIFIC_SRC_DIR_NAME}")

# 输出目录信息
message(STATUS "输出目录: ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}")
message(STATUS "构建类型: ${CMAKE_BUILD_TYPE}")

# 创建输出目录
file(MAKE_DIRECTORY ${CMAKE_LIBRARY_OUTPUT_DIRECTORY})