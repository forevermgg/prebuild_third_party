# generate_metadata_json.cmake - 生成包含元数据的JSON报告

# 获取当前时间戳
string(TIMESTAMP CHECK_TIME "%Y-%m-%dT%H:%M:%S")

# 计算文件的MD5哈希值
if(EXISTS "${SOURCE_FILE}")
    file(MD5 "${SOURCE_FILE}" FILE_MD5)
else()
    set(FILE_MD5 "file_not_found")
endif()

# 读取检测工具的输出
set(DETECTION_RESULTS "")
if(EXISTS "${TEMP_FILE}")
    file(READ "${TEMP_FILE}" DETECTION_RESULTS)
    # 对JSON特殊字符进行转义
    string(REPLACE "\\" "\\\\" DETECTION_RESULTS "${DETECTION_RESULTS}")
    string(REPLACE "\"" "\\\"" DETECTION_RESULTS "${DETECTION_RESULTS}")
    string(REPLACE "\n" "\\n" DETECTION_RESULTS "${DETECTION_RESULTS}")
    string(REPLACE "\r" "\\r" DETECTION_RESULTS "${DETECTION_RESULTS}")
    string(REPLACE "\t" "\\t" DETECTION_RESULTS "${DETECTION_RESULTS}")
else()
    set(DETECTION_RESULTS "检测结果文件未找到")
endif()

# 构建完整的JSON内容
set(JSON_CONTENT "{
  \"metadata\": {
    \"check_time\": \"${CHECK_TIME}\",
    \"file_md5\": \"${FILE_MD5}\",
    \"file_path\": \"${SOURCE_FILE}\",
    \"relative_path\": \"${REL_PATH}\",
    \"file_name\": \"${fname}\"
  },
  \"detection_results\": \"${DETECTION_RESULTS}\"
}")

# 写入JSON文件
file(WRITE "${OUTPUT_FILE}" "${JSON_CONTENT}")
# message(STATUS "[LogChecker] 生成检测报告: ${OUTPUT_FILE}")