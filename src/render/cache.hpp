// src/render/cache.hpp
#pragma once

#include <string>
#include <fstream>
#include <filesystem>

namespace nifdu::render {

inline std::filesystem::path home_cache_dir() {
#ifdef _WIN32
    return std::filesystem::path("C:\\nifdu\\data\\render_cache");
#else
    return std::filesystem::path("data/render_cache");
#endif
}

inline std::filesystem::path home_cache_path() {
    return home_cache_dir() / "home.html";
}

inline bool save_home_html(const std::string& html) {
    try {
        std::filesystem::create_directories(home_cache_dir());
        std::ofstream ofs(home_cache_path(), std::ios::binary | std::ios::trunc);
        if (!ofs) return false;
        ofs.write(html.data(), static_cast<std::streamsize>(html.size()));
        return ofs.good();
    } catch (...) {
        return false;
    }
}

inline std::string load_home_html() {
    try {
        std::ifstream ifs(home_cache_path(), std::ios::binary);
        if (!ifs) return {};
        std::string data((std::istreambuf_iterator<char>(ifs)),
                         std::istreambuf_iterator<char>());
        return data;
    } catch (...) {
        return {};
    }
}

} // namespace nifdu::render
