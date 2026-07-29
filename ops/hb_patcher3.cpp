#include <fstream>
#include <iostream>
#include <string>
#include <filesystem>

static bool has(const std::string& s, const std::string& n){ return s.find(n) != std::string::npos; }

int main(int argc, char** argv){
  std::string cpp = (argc >= 2) ? argv[1] : "C:\\nifdu\\src\\http\\nifdu_http_server80.cpp";
  std::filesystem::path inPath(cpp);
  if(!std::filesystem::exists(inPath)){ std::cerr << "Missing: " << cpp << "\n"; return 2; }

  auto bak = inPath.string() + ".bak_hbpatch3";
  try{ std::filesystem::copy_file(inPath, bak, std::filesystem::copy_options::overwrite_existing); }
  catch(...){ std::cerr << "Backup failed\n"; return 3; }

  std::filesystem::path tmp = inPath; tmp += ".tmp";
  std::ifstream in(inPath, std::ios::binary);
  std::ofstream out(tmp, std::ios::binary);
  if(!in || !out){ std::cerr << "Open failed\n"; return 4; }

  bool replaced=false;
  bool skipping=false;
  bool seen_open=false;
  int depth=0;

  const std::string HB_IF = "if (req.method() == http::verb::get && target == \"/api/brain/heartbeat\")";

  auto emit_new_hb = [&](){
    out <<
R"(    if (req.method() == http::verb::get && target == "/api/brain/heartbeat") {
        // Minimal safe heartbeat (keeps NIFDU's existing send(...) pattern)
        auto res = handle_health(req); // existing helper in your file

        // NOTE: keep it simple: pid + epoch_ms already come from handle_health()
        // If you want extra fields later (host/port/age_ms), we add them AFTER this compiles.
        res.set(http::field::content_type, "application/json; charset=utf-8");
        return send(std::move(res));
    }
)";
    out << "\r\n";
  };

  std::string line;
  while(std::getline(in, line)){
    if(!line.empty() && line.back()=='\r') line.pop_back();

    // Start of heartbeat handler
    if(!skipping && !replaced && has(line, HB_IF)){
      emit_new_hb();
      replaced = true;
      skipping = true;

      // initialize brace tracking from THIS line (may or may not contain '{')
      for(char c: line){ if(c=='{'){ depth++; seen_open=true; } else if(c=='}'){ depth--; } }
      continue; // do not copy old line
    }

    if(skipping){
      // keep consuming old handler until its braces close
      for(char c: line){
        if(c=='{'){ depth++; seen_open=true; }
        else if(c=='}'){ depth--; }
      }
      if(seen_open && depth <= 0){
        skipping = false;
        seen_open = false;
        depth = 0;
      }
      continue; // skip old handler lines
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
