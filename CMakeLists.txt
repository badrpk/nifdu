cmake_minimum_required(VERSION 3.20)

project(
    nifdu
    VERSION 2.1.0
    DESCRIPTION "Autonomous C++ visual product supervisor with graph control plane"
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(CURL REQUIRED)
find_package(nlohmann_json REQUIRED)
find_package(Threads REQUIRED)

add_executable(nifdu-core src/main.cpp)
add_executable(nifdu src/control_plane_main.cpp)

foreach(target nifdu nifdu-core)
    target_compile_options(
        ${target}
        PRIVATE
        -Wall
        -Wextra
        -Wpedantic
    )
endforeach()

target_link_libraries(
    nifdu-core
    PRIVATE
    CURL::libcurl
    nlohmann_json::nlohmann_json
    Threads::Threads
)

target_link_libraries(
    nifdu
    PRIVATE
    nlohmann_json::nlohmann_json
    Threads::Threads
)

include(CTest)
if(BUILD_TESTING AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_pakistan_payments.cpp")
    add_executable(test_pakistan_payments tests/test_pakistan_payments.cpp)
    target_link_libraries(
        test_pakistan_payments
        PRIVATE
        CURL::libcurl
        nlohmann_json::nlohmann_json
        Threads::Threads
    )
    add_test(NAME pakistan_payments COMMAND test_pakistan_payments)
endif()
