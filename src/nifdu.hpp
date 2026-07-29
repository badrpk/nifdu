#pragma once

#include <string>
#include <vector>

namespace nifdu {

struct ComponentInfo {
    const char* name;   // e.g. "HTTP core"
    const char* layer;  // e.g. "Serve", "Droid", "Ops"
    const char* path;   // e.g. "src/http", "src/ai/engine.hpp"
    const char* notes;  // short description
};

struct StartupStep {
    std::string name;   // e.g. "platform.init"
    std::string detail; // e.g. "Loaded C:/nifdu/config/nifdu_platform.toml"
    bool        ok;     // success / failure flag
};

// Return a static list describing everything coded in NIFDU (at a high level).
const std::vector<ComponentInfo>& get_component_manifest();

// Print nice human-readable overview on stdout.
void print_component_manifest();

// Simple banner with version + layers (for startup logs).
void print_banner();

// Record a startup step (you can call this from main.cpp or elsewhere).
void trace_startup_step(const std::string& name,
                        const std::string& detail,
                        bool ok = true);

// Dump all recorded startup steps to stdout.
void dump_startup_trace();

} // namespace nifdu
