# =============================================
# 构建后处理配置
# =============================================
# 修改项: 将构建后处理提取到单独文件

# 构建后处理主函数
function(setup_post_build)
    message(STATUS "设置构建后处理...")

    # 确保输出目录存在
    setup_output_directory()

    # 复制第三方共享库
    setup_third_party_libraries()

    # 设置构建依赖关系
    setup_build_dependencies()

    # 生成构建报告
    generate_build_report()

    message(STATUS "构建后处理设置完成")
endfunction()

# 设置输出目录
function(setup_output_directory)
    if(NOT CMAKE_LIBRARY_OUTPUT_DIRECTORY)
        message(FATAL_ERROR "CMAKE_LIBRARY_OUTPUT_DIRECTORY 未设置")
    endif()

    set(OUTPUT_DIR "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}")
    message(STATUS "创建输出目录: ${OUTPUT_DIR}")

    file(MAKE_DIRECTORY "${OUTPUT_DIR}")

    # 验证目录是否创建成功
    if(NOT EXISTS "${OUTPUT_DIR}")
        message(FATAL_ERROR "无法创建输出目录: ${OUTPUT_DIR}")
    endif()

    # 设置全局变量
    set(POSTBUILD_OUTPUT_DIR "${OUTPUT_DIR}" PARENT_SCOPE)
endfunction()

# 设置第三方库复制
function(setup_third_party_libraries)
    message(STATUS "设置第三方库复制...")

    if(NOT POSTBUILD_OUTPUT_DIR)
        message(FATAL_ERROR "输出目录未设置")
    endif()

    set(THIRD_PARTY_LIBS)

    # 调试信息：打印所有可能的变量
    message(STATUS "调试变量检查:")
    message(STATUS "  - OPENSSL_ROOT_DIR: ${OPENSSL_ROOT_DIR}")
    message(STATUS "  - OPENSSL_ABI_DIR: ${OPENSSL_ABI_DIR}")
    message(STATUS "  - LIBUV_ABI_DIR: ${LIBUV_ABI_DIR}")
    message(STATUS "  - FMT_ABI_DIR: ${FMT_ABI_DIR}")
    message(STATUS "  - ZSTD_ABI_DIR: ${ZSTD_ABI_DIR}")
    message(STATUS "  - CARES_ABI_DIR: ${CARES_ABI_DIR}")  # 添加 c-ares 调试信息

    # OpenSSL 库 - 修复：使用正确的变量名
    if(DEFINED OPENSSL_ABI_DIR AND EXISTS "${OPENSSL_ABI_DIR}/lib")
        message(STATUS "找到 OpenSSL 目录: ${OPENSSL_ABI_DIR}/lib")

        # 检查具体文件是否存在
        if(EXISTS "${OPENSSL_ABI_DIR}/lib/libssl.so")
            list(APPEND THIRD_PARTY_LIBS "${OPENSSL_ABI_DIR}/lib/libssl.so")
            message(STATUS "  - 找到 libssl.so")
        else()
            message(WARNING "libssl.so 未找到: ${OPENSSL_ABI_DIR}/lib/libssl.so")
        endif()

        if(EXISTS "${OPENSSL_ABI_DIR}/lib/libcrypto.so")
            list(APPEND THIRD_PARTY_LIBS "${OPENSSL_ABI_DIR}/lib/libcrypto.so")
            message(STATUS "  - 找到 libcrypto.so")
        else()
            message(WARNING "libcrypto.so 未找到: ${OPENSSL_ABI_DIR}/lib/libcrypto.so")
        endif()
    else()
        message(WARNING "OpenSSL 库路径未找到: ${OPENSSL_ABI_DIR}")
    endif()

    # libuv 库
    if(DEFINED LIBUV_ABI_DIR AND EXISTS "${LIBUV_ABI_DIR}/lib/libuv.so")
        list(APPEND THIRD_PARTY_LIBS "${LIBUV_ABI_DIR}/lib/libuv.so")
        message(STATUS "  - libuv 库: ${LIBUV_ABI_DIR}/lib/libuv.so")
    else()
        message(WARNING "libuv 库路径未找到: ${LIBUV_ABI_DIR}")
    endif()

    # fmt 库
    if(DEFINED FMT_ABI_DIR AND EXISTS "${FMT_ABI_DIR}/lib/libfmt.so")
        list(APPEND THIRD_PARTY_LIBS "${FMT_ABI_DIR}/lib/libfmt.so")
        message(STATUS "  - fmt 库: ${FMT_ABI_DIR}/lib/libfmt.so")
    else()
        message(WARNING "fmt 库路径未找到: ${FMT_ABI_DIR}")
    endif()

    # zstd 库
    if(DEFINED ZSTD_ABI_DIR AND EXISTS "${ZSTD_ABI_DIR}/lib/libzstd.so")
        list(APPEND THIRD_PARTY_LIBS "${ZSTD_ABI_DIR}/lib/libzstd.so")
        message(STATUS "  - zstd 库: ${ZSTD_ABI_DIR}/lib/libzstd.so")
    else()
        message(WARNING "zstd 库路径未找到: ${ZSTD_ABI_DIR}")
    endif()

    # c-ares 库 - 新增支持
    if(DEFINED CARES_ABI_DIR AND EXISTS "${CARES_ABI_DIR}/lib")
        message(STATUS "找到 c-ares 目录: ${CARES_ABI_DIR}/lib")

        # 检查共享库是否存在
        if(EXISTS "${CARES_ABI_DIR}/lib/libcares.so")
            list(APPEND THIRD_PARTY_LIBS "${CARES_ABI_DIR}/lib/libcares.so")
            message(STATUS "  - 找到 libcares.so")
        else()
            # 检查静态库（备选）
            if(EXISTS "${CARES_ABI_DIR}/lib/libcares.a")
                message(STATUS "  - 找到 libcares.a (静态库)")
            else()
                message(WARNING "libcares.so 未找到: ${CARES_ABI_DIR}/lib/libcares.so")
            endif()
        endif()
    else()
        message(WARNING "c-ares 库路径未找到: ${CARES_ABI_DIR}")
    endif()

    # 添加复制命令
    if(THIRD_PARTY_LIBS)
        message(STATUS "配置复制以下库文件:")
        foreach(LIB_FILE IN LISTS THIRD_PARTY_LIBS)
            message(STATUS "  - ${LIB_FILE}")
        endforeach()

        # 修复：使用正确的变量引用方式
        add_custom_command(TARGET ${CMAKE_PROJECT_NAME} POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E echo "开始复制第三方库文件..."
                COMMAND ${CMAKE_COMMAND} -E make_directory "${POSTBUILD_OUTPUT_DIR}"
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                ${THIRD_PARTY_LIBS}
                "${POSTBUILD_OUTPUT_DIR}"
                COMMAND ${CMAKE_COMMAND} -E echo "复制完成: ${POSTBUILD_OUTPUT_DIR}"
                COMMENT "复制第三方共享库到: ${POSTBUILD_OUTPUT_DIR}"
        )

        # 修复：正确的列表长度计算
        list(LENGTH THIRD_PARTY_LIBS LIB_COUNT)
        message(STATUS "  - 配置复制 ${LIB_COUNT} 个库文件")
    else()
        message(WARNING "未找到任何第三方库文件")
    endif()
endfunction()

# 设置构建依赖关系
function(setup_build_dependencies)
    message(STATUS "设置构建依赖关系...")

    # 检查目标是否存在
    if(NOT TARGET ${CMAKE_PROJECT_NAME})
        message(WARNING "主目标 ${CMAKE_PROJECT_NAME} 不存在")
        return()
    endif()

    # 设置依赖关系
    set(DEPENDENCIES)

    if(TARGET easyhttpcpp)
        list(APPEND DEPENDENCIES easyhttpcpp)
        message(STATUS "  - 依赖: easyhttpcpp")
    endif()

    if(TARGET fml)
        list(APPEND DEPENDENCIES fml)
        message(STATUS "  - 依赖: fml")
    endif()

    # 添加 c-ares 依赖（如果目标存在）
    if(TARGET cares_lib)
        list(APPEND DEPENDENCIES cares_lib)
        message(STATUS "  - 依赖: cares_lib")
    endif()

    # 添加依赖
    if(DEPENDENCIES)
        add_dependencies(${CMAKE_PROJECT_NAME} ${DEPENDENCIES})

        # 修复：正确的列表长度计算
        list(LENGTH DEPENDENCIES DEP_COUNT)
        message(STATUS "  - 设置 ${DEP_COUNT} 个构建依赖")
    else()
        message(WARNING "未设置任何构建依赖")
    endif()
endfunction()

# 生成构建报告
function(generate_build_report)
    message(STATUS "生成构建报告...")

    # 计算源文件统计
    if(DEFINED EASY_HTTP_CPP_SRCS)
        list(LENGTH EASY_HTTP_CPP_SRCS EASYHTTPCPP_SRC_COUNT)
    else()
        set(EASYHTTPCPP_SRC_COUNT 0)
    endif()

    if(DEFINED OTHER_SRCS)
        list(LENGTH OTHER_SRCS MAIN_SRC_COUNT)
    else()
        set(MAIN_SRC_COUNT 0)
    endif()

    # 生成详细报告
    message(STATUS "=" * 60)
    message(STATUS "构建配置报告")
    message(STATUS "=" * 60)
    message(STATUS "项目信息:")
    message(STATUS "  - 项目名称: ${CMAKE_PROJECT_NAME}")
    message(STATUS "  - 构建类型: ${CMAKE_BUILD_TYPE}")
    message(STATUS "  - C++ 标准: ${CMAKE_CXX_STANDARD}")
    message(STATUS "  - Android ABI: ${ANDROID_ABI}")
    message(STATUS "  - 输出目录: ${POSTBUILD_OUTPUT_DIR}")

    message(STATUS "源文件统计:")
    message(STATUS "  - easyhttpcpp: ${EASYHTTPCPP_SRC_COUNT} 个源文件")
    message(STATUS "  - 主项目: ${MAIN_SRC_COUNT} 个源文件")

    # 库文件报告
    message(STATUS "将生成的库文件:")
    if(TARGET easyhttpcpp)
        message(STATUS "  - libeasyhttpcpp.so")
    endif()
    if(TARGET fml)
        message(STATUS "  - libfml.so")
    endif()
    if(TARGET cares_lib)
        message(STATUS "  - libcares.so (或静态库)")  # 添加 c-ares 库报告
    endif()
    if(TARGET ${CMAKE_PROJECT_NAME})
        message(STATUS "  - lib${CMAKE_PROJECT_NAME}.so")
    endif()
    message(STATUS "  - Poco 相关库文件")

    # 第三方库状态
    message(STATUS "第三方库状态:")
    check_and_report_library("OpenSSL" "${OPENSSL_ABI_DIR}" "libssl.so")
    check_and_report_library("libuv" "${LIBUV_ABI_DIR}" "libuv.so")
    check_and_report_library("fmt" "${FMT_ABI_DIR}" "libfmt.so")
    check_and_report_library("zstd" "${ZSTD_ABI_DIR}" "libzstd.so")
    check_and_report_library("c-ares" "${CARES_ABI_DIR}" "libcares.so")  # 添加 c-ares 状态报告

    message(STATUS "=" * 60)
endfunction()

# 检查并报告库状态
function(check_and_report_library LIB_NAME LIB_DIR LIB_FILE)
    if(DEFINED LIB_DIR AND EXISTS "${LIB_DIR}/lib/${LIB_FILE}")
        message(STATUS "  - ✓ ${LIB_NAME}: 已配置 (${LIB_DIR})")
    else()
        message(STATUS "  - ✗ ${LIB_NAME}: 未配置")
    endif()
endfunction()

# 安装后处理（可选）
function(setup_install_rules)
    message(STATUS "设置安装规则...")

    # 安装主库
    if(TARGET ${CMAKE_PROJECT_NAME})
        install(TARGETS ${CMAKE_PROJECT_NAME}
                LIBRARY DESTINATION lib
                ARCHIVE DESTINATION lib
                RUNTIME DESTINATION bin
        )
    endif()

    # 安装依赖库
    if(TARGET easyhttpcpp)
        install(TARGETS easyhttpcpp
                LIBRARY DESTINATION lib
                ARCHIVE DESTINATION lib
        )
    endif()

    if(TARGET fml)
        install(TARGETS fml
                LIBRARY DESTINATION lib
                ARCHIVE DESTINATION lib
        )
    endif()

    # 安装 c-ares 库（如果目标存在）
    if(TARGET cares_lib)
        install(TARGETS cares_lib
                LIBRARY DESTINATION lib
                ARCHIVE DESTINATION lib
        )
    endif()

    # 安装头文件
    install(DIRECTORY include/
            DESTINATION include
            FILES_MATCHING PATTERN "*.h" PATTERN "*.hpp"
    )

    # 安装 c-ares 头文件（如果路径存在）
    if(DEFINED CARES_ABI_DIR AND EXISTS "${CARES_ABI_DIR}/include")
        install(DIRECTORY "${CARES_ABI_DIR}/include/"
                DESTINATION include
                FILES_MATCHING PATTERN "*.h"
        )
    endif()

    message(STATUS "安装规则设置完成")
endfunction()

# 清理构建产物
function(setup_clean_targets)
    message(STATUS "设置清理目标...")

    # 添加自定义清理目标
    add_custom_target(clean_all
            COMMAND ${CMAKE_COMMAND} -E remove_directory ${POSTBUILD_OUTPUT_DIR}
            COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_CURRENT_BINARY_DIR}
            COMMENT "清理所有构建产物"
    )

    # 添加第三方库清理目标
    add_custom_target(clean_third_party
            COMMAND ${CMAKE_COMMAND} -E remove_directory ${POSTBUILD_OUTPUT_DIR}
            COMMENT "清理第三方库文件"
    )

    message(STATUS "清理目标设置完成")
endfunction()