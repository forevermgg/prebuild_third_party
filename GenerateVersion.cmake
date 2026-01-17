
message("GenerateVersion.cmake CMAKE_CURRENT_SOURCE_DIR: ${CMAKE_CURRENT_SOURCE_DIR}")

message("GIT_COMMIT: ${GIT_COMMIT}")
add_definitions(-DGIT_COMMIT_SHA1="${GIT_COMMIT}")

execute_process(COMMAND bash "-c" "git log|head -n 1|awk '{printf $2}'"
        OUTPUT_VARIABLE GIT_COMMIT_ID
        ERROR_QUIET)

message("GIT_COMMIT_ID: ${GIT_COMMIT_ID}")
# Check whether we got any revision (which isn't
# always the case, e.g. when someone downloaded a zip
# file from Github instead of a checkout)
if ("${GIT_COMMIT_ID}" STREQUAL "")
    set(GIT_COMMIT_ID "N/A")
    set(GIT_TAG "N/A")
    set(GIT_BRANCH "N/A")
else()
    execute_process(
            COMMAND git describe --exact-match --tags
            OUTPUT_VARIABLE GIT_TAG ERROR_QUIET)
    execute_process(
            COMMAND git rev-parse --abbrev-ref HEAD
            OUTPUT_VARIABLE GIT_BRANCH)

    string(STRIP "${GIT_COMMIT_ID}" GIT_COMMIT_ID)
    string(STRIP "${GIT_COMMIT_ID}" GIT_COMMIT_ID)
    string(STRIP "${GIT_TAG}" GIT_TAG)
    string(STRIP "${GIT_BRANCH}" GIT_BRANCH)
endif()
message("GIT_TAG: ${GIT_TAG}")
message("GIT_BRANCH: ${GIT_BRANCH}")
set(VERSION "#ifndef FOREVER_VERSION_H
#define FOREVER_VERSION_H

namespace FOREVER {
const char* const GIT_COMMIT_ID = \"${GIT_COMMIT_ID}\";
const char* const GIT_TAG = \"${GIT_TAG}\";
const char* const GIT_BRANCH = \"${GIT_BRANCH}\";
} // namespace FOREVER

#endif // FOREVER_VERSION_H
")

if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/src/version.cpp)
    file(READ ${CMAKE_CURRENT_SOURCE_DIR}/src/version.h VERSION_)
else()
    set(VERSION_ "")
endif()

if (NOT "${VERSION}" STREQUAL "${VERSION_}")
    file(WRITE ${CMAKE_CURRENT_SOURCE_DIR}/src/version.h "${VERSION}")
endif()

ADD_CUSTOM_COMMAND(
        OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/src/version.h
        ${CMAKE_CURRENT_BINARY_DIR}/_version.h
        COMMAND ${CMAKE_COMMAND} -P
        ${CMAKE_CURRENT_SOURCE_DIR}/cmake/Version.cmake)


macro(get_git_hash GIT_COMMIT_ID)   # 宏的开始
    find_package(Git QUIET)     # 查找Git，QUIET静默方式不报错
    if(GIT_FOUND)
        execute_process(COMMAND bash "-c" "git log|head -n 1|awk '{printf $2}'"
                OUTPUT_VARIABLE ${GIT_COMMIT_ID}
                ERROR_QUIET)

        execute_process(
                COMMAND git rev-parse --abbrev-ref HEAD
                OUTPUT_VARIABLE ${GIT_BRANCH})
    endif()
endmacro()                      # 宏的结束

configure_file(
        ${CMAKE_CURRENT_SOURCE_DIR}/src/git_version.h.in  # 输入
        ${CMAKE_CURRENT_SOURCE_DIR}/src/git_version.h            # 输出
        @ONLY     # 只接受形如@VAR@的占位符
)