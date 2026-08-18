cmake_minimum_required(VERSION 3.20)

project(
    nifdu
    VERSION 2.1.0
    DESCRIPTION "Autonomous C++ visual product supervisor & NIFDU Core Engine"
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

include_directories(include)

find_package(CURL REQUIRED)
find_package(nlohmann_json REQUIRED)
find_package(Threads REQUIRED)

add_compile_options(-O3 -march=native -ffast-math)

add_executable(
    nifdu
    src/main.cpp
    src/agent3.cpp
    src/telemetry.cpp
    src/realtime.cpp
    src/lang_adapter.cpp
    src/lang_graph.cpp
    src/lang_smith.cpp
    src/pakistan_payments.cpp
    src/http_server.cpp
    src/simd_data_engine.cpp
    src/postgres_store.cpp
    src/git_sync_engine.cpp
    src/federated_sync.cpp
    src/grok_client.cpp
    src/neuron_engine.cpp
    src/spiking_weight_importer.cpp
)

target_link_libraries(
    nifdu
    PRIVATE
    CURL::libcurl
    nlohmann_json::nlohmann_json
    Threads::Threads
)

# Native disk-first / hot-index memory kernel.
add_library(
    nifdu_memory_core
    src/brain_memory.cpp
)

target_include_directories(
    nifdu_memory_core
    PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(
    nifdu_memory_core
    PUBLIC
    nlohmann_json::nlohmann_json
    Threads::Threads
)

add_executable(
    nifdu-memory
    src/brain_memory_cli.cpp
)

target_link_libraries(
    nifdu-memory
    PRIVATE
    nifdu_memory_core
)

add_executable(
    test_brain_memory
    tests/test_brain_memory.cpp
)

target_link_libraries(
    test_brain_memory
    PRIVATE
    nifdu_memory_core
)


add_executable(
    test_100_tasks
    tests/benchmark_100_tasks_self_improvement.cpp
    src/git_sync_engine.cpp
    src/federated_sync.cpp
    src/simd_data_engine.cpp
    src/postgres_store.cpp
    src/neuron_engine.cpp
    src/spiking_weight_importer.cpp
)

target_link_libraries(
    test_100_tasks
    PRIVATE
    Threads::Threads
)

add_executable(
    test_million_neuron_loops
    tests/benchmark_million_neuron_loops.cpp
    src/neuron_engine.cpp
    src/spiking_weight_importer.cpp
)

target_link_libraries(
    test_million_neuron_loops
    PRIVATE
    Threads::Threads
)

add_executable(
    test_compare_spiking_llm_vs_dense_transformer
    tests/test_compare_spiking_llm_vs_dense_transformer.cpp
    src/neuron_engine.cpp
    src/spiking_weight_importer.cpp
)

target_link_libraries(
    test_compare_spiking_llm_vs_dense_transformer
    PRIVATE
    Threads::Threads
)

add_executable(
    test_stdp_spiking_llm_training
    tests/test_stdp_spiking_llm_training.cpp
    src/neuron_engine.cpp
    src/spiking_weight_importer.cpp
)

target_link_libraries(
    test_stdp_spiking_llm_training
    PRIVATE
    Threads::Threads
)

add_executable(
    test_neuron_capabilities
    tests/test_neuron_capabilities.cpp
    src/neuron_engine.cpp
    src/spiking_weight_importer.cpp
)

target_link_libraries(
    test_neuron_capabilities
    PRIVATE
    Threads::Threads
)

add_executable(
    test_4_frameworks_10_tasks_benchmark
    tests/test_4_frameworks_10_tasks_benchmark.cpp
    src/neuron_engine.cpp
    src/spiking_weight_importer.cpp
    src/simd_data_engine.cpp
)

target_link_libraries(
    test_4_frameworks_10_tasks_benchmark
    PRIVATE
    Threads::Threads
)
