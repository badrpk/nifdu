// hb_patcher.cpp - replaces the entire /api/brain/heartbeat handler block safely
// Build (MSVC): cl /nologo /EHsc /std:c++20 hb_patcher.cpp
#include <fstream>
#include <iostream>
#include <string>
#include <filesystem>

static bool contains(const std::string& s, const std::string& needle){
    return s.find(needle) != std::string::npos;
}

static void count_braces(const std::string& line, int& depth){
    for(char c: line){
        if(c=='{') depth++;
        else if(c=='}') depth--;
    }
}

int main(int argc, char** argv){
    std::string cpp = (argc >= 2) ? argv[1] : "C:\\nifdu\\src\\http\\nifdu_http_server80.cpp";

    std::filesystem::path inPath(cpp);
    if(!std::filesystem::exists(inPath)){
        std::cerr << "Missing: " << cpp << "\n";
        return 2;
    }

    auto bak = inPath.string() + ".bak_hbpatch";
    try{
        std::filesystem::copy_file(inPath, bak, std::filesystem::copy_options::overwrite_existing);
    }catch(...){
        std::cerr << "Backup failed\n";
        return 3;
    }

    std::filesystem::path tmpPath = inPath;
    tmpPath += ".tmp";

    std::ifstream in(inPath, std::ios::binary);
    std::ofstream out(tmpPath, std::ios::binary);
    if(!in || !out){
        std::cerr << "Open failed\n";
        return 4;
    }

    bool saw_sstream = false;
    bool saw_chrono  = false;
    bool inserted_includes = false;

    bool replaced_handler = false;
    bool skipping_old = false;
    int  skip_depth = 0;

    const std::string hb_if =
        "if (req.method() == http::verb::get && target == \"/api/brain/heartbeat\")";

    std::string line;
    while(std::getline(in, line)){
        if(contains(line, "#include <sstream>")) saw_sstream = true;
        if(contains(line, "#include <chrono>"))  saw_chrono  = true;

        // Insert missing includes once, right after a stable include anchor
        if(!inserted_includes && (!saw_sstream || !saw_chrono)){
            if(contains(line, "#include <filesystem>") || contains(line, "#include <fstream>")){
                out << line << "\r\n";
                if(!saw_sstream) out << "#include <sstream>\r\n";
                if(!saw_chrono)  out << "#include <chrono>\r\n";
                inserted_includes = true;
                continue;
            }
        }

        // If we're skipping the old heartbeat handler, consume until brace depth returns to 0.
        if(skipping_old){
            count_braces(line, skip_depth);
            if(skip_depth <= 0){
                skipping_old = false;
            }
            continue;
        }

        // Detect the heartbeat IF line and replace the entire block.
        if(!replaced_handler && contains(line, hb_if)){
            // Start skipping old handler from its first '{' to matching '}'
            skipping_old = true;
            skip_depth = 0;
            count_braces(line, skip_depth); // this line contains '{' in your file

            // Emit our known-good full handler block (drop-in replacement)
            out <<
R"(    if (req.method() == http::verb::get && target == "/api/brain/heartbeat") {
        auto res = handle_health(req);
        res.set(http::field::content_type, "application/json");
        res.set(http::field::cache_control, "no-store");
        res.keep_alive(req.keep_alive());

        // epoch_ms + now_ms
        long long epoch_ms = 0;
        long long now_ms = 0;
        try{
            auto now = std::chrono::system_clock::now();
            now_ms = (long long)std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch()).count();
            epoch_ms = now_ms; // keep existing meaning: "server time at response"
        }catch(...){}

        // Host header -> host + local_port (best effort)
        const std::string hb_host_hdr = std::string(req[http::field::host]);
        int hb_local_port = 80;
        try{
            auto pos = hb_host_hdr.rfind(':');
            if(pos != std::string::npos && hb_host_hdr.find(']') == std::string::npos){
                const std::string tail = hb_host_hdr.substr(pos + 1);
                bool all_digits = !tail.empty();
                for(char ch : tail){ if(ch < '0' || ch > '9'){ all_digits = false; break; } }
                if(all_digits){
                    int p = std::stoi(tail);
                    if(p > 0 && p <= 65535) hb_local_port = p;
                }
            }
        }catch(...){}

        auto hb_json_escape = [](const std::string& in)->std::string{
            std::string out; out.reserve(in.size()+8);
            for(char c : in){
                if(c == '\\') out += "\\\\";
                else if(c == '"') out += "\\\"";
                else out += c;
            }
            return out;
        };

        // Age is 0 here because epoch_ms is "now"; if you later store boot_time_ms, compute real age.
        long long hb_age_ms = 0;

        std::ostringstream ss;
        ss << "{\"ok\":true"
           << ",\"pid\":" << pid
           << ",\"epoch_ms\":" << epoch_ms
           << ",\"now_ms\":" << now_ms
           << ",\"age_ms\":" << hb_age_ms
           << ",\"local_port\":" << hb_local_port
           << ",\"host\":\"" << hb_json_escape(hb_host_hdr) << "\""
           << "}";
        res.body() = ss.str();
        res.prepare_payload();
        return send(std::move(res));
    }
)" << "\r\n";

            replaced_handler = true;
            continue;
        }

        // Normal passthrough
        out << line << "\r\n";
    }

    in.close();
    out.close();

    if(!replaced_handler){
        std::cerr << "Did not find heartbeat IF line to replace.\n";
        std::cerr << "Restoring original from: " << bak << "\n";
        try{ std::filesystem::copy_file(bak, inPath, std::filesystem::copy_options::overwrite_existing); }catch(...){}
        return 10;
    }

    try{
        std::filesystem::copy_file(tmpPath, inPath, std::filesystem::copy_options::overwrite_existing);
        std::filesystem::remove(tmpPath);
    }catch(...){
        std::cerr << "Swap failed\n";
        return 11;
    }

    std::cout << "OK: replaced heartbeat handler. Backup: " << bak << "\n";
    return 0;
}
