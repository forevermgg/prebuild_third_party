# 定义环境变量
set(ENV{QCI_BUILD_ID} "999")
set(ENV{QCI_BUILD_NUMBER} "999")
set(ENV{QCI_JOB_ID} "999")

# 获取环境变量 并打印
message("QCI_BUILD_ID: $ENV{QCI_BUILD_ID}")
message("QCI_JOB_ID: $ENV{QCI_JOB_ID}")
message("QCI_BUILD_NUMBER: $ENV{QCI_BUILD_NUMBER}")

execute_process(
        COMMAND bash "-c" "git log|head -n 1|awk '{printf $2}'"
        OUTPUT_VARIABLE GIT_COMMIT
)