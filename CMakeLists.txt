cmake_minimum_required(VERSION 3.20)

project(
    nifdu
    VERSION 2.0.0
    DESCRIPTION "Autonomous C++ visual product supervisor & NIFDU Core Engine"
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(CURL REQUIRED)
find_package(nlohmann_json REQUIRED)
find_package(Threads REQUIRED)

set(
    NIFDU_CORE_SOURCES
    src/agent3.cpp
    src/http_server.cpp
    src/lang_adapter.cpp
    src/lang_graph.cpp
    src/lang_smith.cpp
    src/pakistan_payments.cpp
    src/realtime.cpp
    src/telemetry.cpp
)

if(WIN32)
    list(APPEND NIFDU_CORE_SOURCES src/truth_engine.cpp)
endif()

add_library(
    nifdu_core
    STATIC
    ${NIFDU_CORE_SOURCES}
)

target_include_directories(
    nifdu_core
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include
        ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_compile_options(
    nifdu_core
    PRIVATE
        -Wall
        -Wextra
        -Wpedantic
)

target_link_libraries(
    nifdu_core
    PUBLIC
        CURL::libcurl
        nlohmann_json::nlohmann_json
        Threads::Threads
)

add_executable(
    nifdu
    src/main.cpp
)

target_compile_options(
    nifdu
    PRIVATE
        -Wall
        -Wextra
        -Wpedantic
)

target_link_libraries(
    nifdu
    PRIVATE
        nifdu_core
)

include(CTest)

if(
    BUILD_TESTING
    AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_pakistan_payments.cpp"
)
    add_executable(
        test_pakistan_payments
        tests/test_pakistan_payments.cpp
    )

    target_link_libraries(
        test_pakistan_payments
        PRIVATE
            nifdu_core
    )

    add_test(
        NAME pakistan_payments
        COMMAND test_pakistan_payments
    )

    set_tests_properties(
        pakistan_payments
        PROPERTIES
            TIMEOUT 30
    )
endif()
