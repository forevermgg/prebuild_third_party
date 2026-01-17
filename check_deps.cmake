# Copyright 2010-2025 Google LLC
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Check dependencies

if(NOT TARGET absl::base)
    message(FATAL_ERROR "Target absl::base not available.")
endif()
set(ABSL_DEPS
        absl::core_headers
        absl::absl_check
        absl::absl_log
        absl::algorithm
        absl::base
        absl::bind_front
        absl::bits
        absl::btree
        absl::check
        absl::cleanup
        absl::cord
        absl::core_headers
        absl::die_if_null
        absl::debugging
        absl::dynamic_annotations
        absl::flags
        absl::flat_hash_map
        absl::flat_hash_set
        absl::function_ref
        absl::flags_commandlineflag
        absl::flags_marshalling
        absl::flags_parse
        absl::flags_reflection
        absl::flags_usage
        absl::hash
        absl::layout
        absl::log_initialize
        absl::log_severity
        absl::log
        absl::log_flags
        absl::log_globals
        absl::log_initialize
        absl::log_internal_message
        absl::memory
        absl::node_hash_map
        absl::node_hash_set
        absl::optional
        absl::span
        absl::status
        absl::statusor
        absl::strings
        absl::synchronization
        absl::time
        absl::type_traits
        absl::utility
        absl::variant
        absl::cord
        absl::random_random
        absl::raw_hash_set
        absl::hash
        absl::leak_check
        absl::memory
        absl::meta
        absl::stacktrace
        absl::status
        absl::statusor
        absl::str_format
        absl::strings
        absl::synchronization
        absl::time
        absl::any
        absl::raw_logging_internal
)

#[[
if(NOT TARGET protobuf::libprotobuf)
    message(FATAL_ERROR "Target protobuf::libprotobuf not available.")
endif()
]]
