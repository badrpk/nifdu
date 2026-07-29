#pragma once
#include <string>

struct NifduConfig {
  std::string host = "127.0.0.1";
  unsigned short port = 8080;
  std::string static_root = "www";
  std::string cert_file; // optional for TLS (future)
  std::string key_file;  // optional for TLS (future)
};
