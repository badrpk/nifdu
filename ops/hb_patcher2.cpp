#include <fstream>
#include <iostream>
#include <string>
#include <filesystem>

static bool has(const std::string& s, const std::string& n){ return s.find(n) != std::string::npos; }

int main(int argc, char** argv){
  std::string cpp = (argc >= 2) ? argv[1] : "C:\\nifdu\\src\\http\\nifdu_http_server80.cpp";
  std::filesystem::path inPath(cpp);
  if(!std::filesystem::exists(inPath)){ std::cerr << "Missing: " << cpp << "\n"; return 2; }

  auto bak = inPath.string() + ".bak_hbpatch2";
  try{ std::filesystem::copy_file(inPath, bak, std::filesystem::copy_options::overwrite_existing); }
  catch(...){ std::cerr << "Backup failed\n"; return 3; }

  std::filesystem::path tmp = inPath; tmp += ".tmp";
  std::ifstream in(inPath, std::ios::binary);
  std::ofstream out(tmp, std::ios::binary);
  if(!in || !out){ std::cerr << "Open failed\n"; return 4; }

  bool saw_sstream=false, injected_sstream=false;
  bool saw_process=false, injected_process=false;

  bool replaced=false;
  bool skipping=false;
  int  depth=0;

  const std::string HB_IF = "if (req.method() == http::verb::get && target == \"/api/brain/heartbeat\")";

  auto emit_new_hb = [&](){
    out <<
R"(    if (req.method() == http::verb::get && target == "/api/brain/heartbeat") {
        // Heartbeat: write directly (avoid WinSock send() collision)
        int pid = 0;
        try { pid = _getpid(); } catch(...) { pid = 0; }

        long long now_ms = 0;
        long long epoch_ms = 0;
        try{
            auto now = std::chrono::system_clock::now();
            now_ms = (long long)std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch()).count();
            epoch_ms = now_ms;
        }catch(...){}

        long long age_ms = 0;

        std::string host_hdr;
        try { host_hdr = std::string(req[http::field::host]); } catch(...) {}
        int local_port = 80;
        try{
            auto pos = host_hdr.rfind(':');
            if(pos != std::string::npos && host_hdr.find(']') == std::string::npos){
                std::string tail = host_hdr.substr(pos+1);
                bool all_digits = !tail.empty();
                for(char ch: tail){ if(ch < '0' || ch > '9'){ all_digits=false; break; } }
                if(all_digits){
                    int p = std::stoi(tail);
                    if(p > 0 && p <= 65535) local_port = p;
                }
            }
        }catch(...){}

        auto json_escape = [](const std::string& in)->std::string{
            std::string out; out.reserve(in.size()+8);
            for(char c: in){
                if(c=='\\') out += "\\\\";
                else if(c=='"') out += "\\\"";
                else out += c;
            }
            return out;
        };

        std::ostringstream ss;
        ss << "{\"ok\":true"
           << ",\"pid\":" << pid
           << ",\"epoch_ms\":" << epoch_ms
           << ",\"now_ms\":" << now_ms
           << ",\"age_ms\":" << age_ms
           << ",\"local_port\":" << local_port
           << ",\"host\":\"" << json_escape(host_hdr) << "\""
           << "}";

        http::response<http::string_body> res{http::status::ok, req.version()};
        res.set(http::field::server, "nifdu");
        res.set(http::field::content_type, "application/json; charset=utf-8");
        res.keep_alive(req.keep_alive());
        res.body() = ss.str();
        res.prepare_payload();

        boost::system::error_code ec;
        http::write(socket, res, ec);
        return;
    }
)";
    out << "\r\n";
  };

  std::string line;
  while(std::getline(in, line)){
    // normalize: strip trailing CR if present
    if(!line.empty() && line.back()=='\r') line.pop_back();

    // includes
    if(has(line, "#include <sstream>")) saw_sstream = true;
    if(has(line, "#include <process.h>")) saw_process = true;

    // inject includes right after <filesystem> or <fstream>
    if(!saw_sstream && !injected_sstream && (has(line,"#include <filesystem>") || has(line,"#include <fstream>"))){
      out << line << "\r\n" << "#include <sstream>\r\n";
      injected_sstream = true;
      continue;
    }
    if(!saw_process && !injected_process && (has(line,"#include <sstream>") || has(line,"#include <filesystem>") || has(line,"#include <fstream>"))){
      // insert process.h immediately after first of these we encounter (but only once)
      out << line << "\r\n" << "#include <process.h>\r\n";
      injected_process = true;
      continue;
    }

    // If we are not in skip mode, detect heartbeat handler start
    if(!skipping && !replaced && has(line, HB_IF)){
      // write the if-line as-is
      out << line << "\r\n";

      // next lines: we must consume until we fully close its brace block
      // Find first '{' by reading subsequent lines if needed
      std::string l2;
      while(std::getline(in, l2)){
        if(!l2.empty() && l2.back()=='\r') l2.pop_back();
        // count braces
        for(char c: l2){ if(c=='{') depth++; else if(c=='}') depth--; }

        // once we see the opening '{', we start skipping
        out << l2 << "\r\n";
        if(has(l2, "{")){
          skipping = true;
          break;
        }
      }
      // Now we are inside the old block; replace it by:
      // - remove what we just wrote for the old block contents? We cannot “unwrite”.
      // So: instead, we must do it differently: we should *not* write old block at all.
      // Therefore, abort here with message if heartbeat is formatted unexpectedly.
      std::cerr << "Heartbeat block format unexpected (brace on separate line). Put '{' on same line as heartbeat if.\n";
      std::cerr << "Restore from: " << bak << "\n";
      try{ std::filesystem::copy_file(bak, inPath, std::filesystem::copy_options::overwrite_existing); }catch(...){}
      return 20;
    }

    // Better approach: heartbeat if-line with '{' same line
    if(!skipping && !replaced && has(line, HB_IF) && has(line,"{")){
      // start skipping old block (count braces on this line)
      depth = 0;
      for(char c: line){ if(c=='{') depth++; else if(c=='}') depth--; }
      // emit the NEW handler instead
      emit_new_hb();
      replaced = true;
      skipping = true;
      continue;
    }

    if(skipping){
      // update brace depth
      for(char c: line){ if(c=='{') depth++; else if(c=='}') depth--; }
      if(depth <= 0){
        skipping = false;
      }
      continue; // skip old lines
    }

    out << line << "\r\n";
  }

  in.close(); out.close();

  if(!replaced){
    std::cerr << "Did not find/replace heartbeat handler.\nRestore from: " << bak << "\n";
    try{ std::filesystem::copy_file(bak, inPath, std::filesystem::copy_options::overwrite_existing); }catch(...){}
    return 10;
  }

  try{
    std::filesystem::copy_file(tmp, inPath, std::filesystem::copy_options::overwrite_existing);
    std::filesystem::remove(tmp);
  }catch(...){
    std::cerr << "Swap failed\n";
    return 11;
  }

  std::cout << "OK: replaced heartbeat handler. Backup: " << bak << "\n";
  return 0;
}
