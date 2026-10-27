ninfer_add_test(ninfer_admission_policy_test SOURCES "${CMAKE_CURRENT_LIST_DIR}/../test_admission_policy.cpp"
  LIBRARIES ninfer_runtime_support)

# Pins the historical stuck-latch rule and the NINFER_KV_STUCK_LATCH parsing that the P0 patch
# changed: the default must never report the Engine unavailable, and only explicit truthy values
# may enable the historical latch.
ninfer_add_test(ninfer_stuck_latch_test SOURCES "${CMAKE_CURRENT_LIST_DIR}/../test_stuck_latch.cpp")

# Reassembles the emitted device-profile literals and compares them with the JSON source, so a
# future change to the CMake chunking cannot silently corrupt or truncate the embedded route table.
add_test(NAME ninfer_device_profiles_embedded
         COMMAND ${CMAKE_COMMAND}
           -DJSON_FILE=${PROJECT_SOURCE_DIR}/src/runtime/engine/device_profiles.json
           -DGENERATED_FILE=${CMAKE_BINARY_DIR}/src/runtime/engine/device_profiles_builtin.cpp
           -P ${PROJECT_SOURCE_DIR}/cmake/VerifyEmbeddedProfiles.cmake)

ninfer_add_test(ninfer_context_cost_test SOURCES "${CMAKE_CURRENT_LIST_DIR}/../test_context_cost.cpp"
  LIBRARIES ninfer_runtime_support ninfer::json)

ninfer_add_test(ninfer_resource_manager_test SOURCES "${CMAKE_CURRENT_LIST_DIR}/../test_resource_manager.cpp"
  LIBRARIES ninfer_runtime_support)

ninfer_add_test(ninfer_kv_capacity_test SOURCES "${CMAKE_CURRENT_LIST_DIR}/../test_kv_capacity.cpp"
  LIBRARIES ninfer_runtime_support)

ninfer_add_test(ninfer_device_profile_test SOURCES "${CMAKE_CURRENT_LIST_DIR}/../test_device_profile.cpp"
  LIBRARIES ninfer_runtime_support)

ninfer_add_test(ninfer_context_cache_defaults_test
  SOURCES "${CMAKE_CURRENT_LIST_DIR}/../test_context_cache_defaults.cpp"
  LIBRARIES ninfer_engine ninfer_core ninfer::json)

ninfer_add_test(ninfer_sampling_defaults_test
  SOURCES "${CMAKE_CURRENT_LIST_DIR}/../test_sampling_defaults.cpp"
  LIBRARIES ninfer_engine ninfer_core)

ninfer_add_test(ninfer_prefix_cache_index_test
  SOURCES "${CMAKE_CURRENT_LIST_DIR}/../test_prefix_cache_index.cpp"
  LIBRARIES ninfer_runtime_support)
