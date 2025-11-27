cmake_minimum_required(VERSION 3.20)
project(nifdu LANGUAGES CXX)

add_compile_definitions(
    TOML_HEADER_ONLY=1
    _ALLOW_COMPILER_AND_STL_VERSION_MISMATCH
)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_TOOLCHAIN_FILE "C:/vcpkg/scripts/buildsystems/vcpkg.cmake"
    CACHE FILEPATH "vcpkg toolchain"
)

if (MSVC)
    add_compile_options(/Zc:char8_t /bigobj)
    add_compile_definitions(_WIN32_WINNT=0x0A00 WIN32_LEAN_AND_MEAN)
endif()

find_package(Boost CONFIG REQUIRED COMPONENTS system filesystem thread)
find_package(OpenSSL REQUIRED)
find_package(nlohmann_json CONFIG REQUIRED)
find_package(tomlplusplus CONFIG REQUIRED)

add_executable(nifdu
    src/main.cpp src/truth_engine.cpp src/lead_api_shim.cpp
    src/nifdu_ai_client.cpp
    src/nifdu_routes.cpp
    src/nifdu_platform.cpp

    src/ai/engine.cpp
    src/ai/av_engine.cpp

    src/http/api_chat.cpp
    src/http/handlers_ai.cpp
)

target_link_libraries(nifdu PRIVATE
    Boost::system
    Boost::filesystem
    Boost::thread
    OpenSSL::SSL
    OpenSSL::Crypto
    C:/vcpkg/installed/x64-windows/lib/libpq.lib
    nlohmann_json::nlohmann_json
)

target_include_directories(nifdu PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

# REMOVED BROKEN AV target_sources (will use real config later)






# NIFDU AV sprite handler
target_sources(nifdu PRIVATE src/http/api_av_sprite.cpp)


# NIFDU AV control handler
target_sources(nifdu PRIVATE src/http/api_av_control.cpp)









