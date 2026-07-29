#include "nifdu.hpp"

#include <iostream>
#include <mutex>

namespace nifdu {

// ==============================
// 1. Component Manifest
// ==============================
//
// This is the central map of NIFDU. Whenever you add a major module or folder,
// update this list so it always reflects "everything being coded in NIFDU".
//

static const ComponentInfo kComponentsRaw[] = {

    // ---- Core / Entry ----
    {
        "Core entry / main",
        "Serve",
        "src/main.cpp",
        "Entry point: initializes AI, loads platform config, starts HTTP server."
    },
    {
        "NIFDU manifest / trace",
        "Ops",
        "src/nifdu.cpp, src/nifdu.hpp",
        "This file: central manifest of components and startup tracing utilities."
    },

    // ---- Serve (HTTP & routing) ----
    {
        "HTTP server core",
        "Serve",
        "src/http",
        "Low-level HTTP/TCP handling, request parsing, response writing."
    },
    {
        "Routing / site config",
        "Serve",
        "src/nifdu_routes.hpp",
        "Route matching for hosts and paths; maps URLs to static files and APIs."
    },
    {
        "Platform / vhosts / ACME",
        "Serve",
        "src/nifdu_platform.hpp, config/nifdu_platform.toml",
        "Platform configuration (bind/port, vhosts, ACME challenge directory)."
    },

    // ---- Droid (AI) ----
    {
        "AI engine",
        "Droid",
        "src/ai/engine.hpp, src/ai",
        "Qwen / llama.cpp integration; completion endpoints used by /api/vibe, /api/chat, etc."
    },
    {
        "Models directory",
        "Droid",
        "C:/nifdu/models",
        "Local GGUF models (e.g. qwen2.5-1.5b-instruct-q4_k_m.gguf) used by NIFDU AI."
    },

    // ---- Data / DB ----
    {
        "PostgreSQL integration",
        "Data",
        "libpq (PostgreSQL C client), db: nifdu_com_db",
        "Database for projects, prompts, generated HTML and future multi-tenant state."
    },
    {
        "Projects table",
        "Data",
        "nifdu_com_db.public.projects",
        "Holds vibe-generated projects (prompt, code, status, published flag, timestamps)."
    },

    // ---- Render (front-ends) ----
    {
        "Webroot for nifdu.com",
        "Render",
        "C:/webroot/nifdu.com/www",
        "Static HTML front-end for NIFDU Studio (builder, preview, etc.)."
    },
    {
        "Webroot for sophyane.com",
        "Render",
        "C:/webroot/sophyane.com/www",
        "Sophyane front-end; future integration with NIFDU AI and projects."
    },

    // ---- Pack (future) ----
    {
        "Pack / installers (planned)",
        "Pack",
        "src/pack",
        "Future: C++ packager for EXE / APK / PWA build artifacts."
    },

    // ---- Stack (planner, blueprints) ----
    {
        "Stack / project planner (WIP)",
        "Stack",
        "src/droid, src/nifdu",
        "Logical brain turning specs into blueprints, file trees and jobs."
    },

    // ---- Ops / Metrics ----
    {
        "Ops / service management",
        "Ops",
        "src/ops",
        "Future: health checks, service manager, watchdog, restart policies."
    },
    {
        "Metrics / observability",
        "Ops",
        "src/metrics",
        "Future: HTTP/AI metrics (latency, throughput, error counts) for dashboards."
    },

    // ---- AI Studio APIs ----
    {
        "AI Studio: /api/vibe",
        "Droid",
        "src/main.cpp (handle_api2)",
        "Turns a natural-language web spec into a full HTML project saved to DB."
    },
    {
        "AI Studio: /api/projects/accept",
        "Droid",
        "src/main.cpp (handle_api2)",
        "Publishes generated HTML into C:/webroot/.../projects/<id>.html and marks DB row as published."
    },
    {
        "AI Studio: /api/chat, /api/compile, /api/project, /api/train, /api/run",
        "Droid",
        "src/main.cpp (handle_api2)",
        "General NIFDU assistants for chat, C++ review, project planning, training stubs and future sandbox."
    },

    // ---- TLS / ACME ----
    {
        "ACME HTTP-01 challenge handler",
        "Serve",
        "src/main.cpp (handle_acme), nifdu_platform",
        "Serves /.well-known/acme-challenge/<token> from platform ACME directory."
    }
};

const std::vector<ComponentInfo>& get_component_manifest()
{
    static std::vector<ComponentInfo> manifest(
        std::begin(kComponentsRaw),
        std::end(kComponentsRaw)
    );
    return manifest;
}

void print_component_manifest()
{
    std::cout << "\n=== NIFDU COMPONENT MANIFEST ===\n\n";

    const auto& manifest = get_component_manifest();
    for (const auto& c : manifest) {
        std::cout << " - [" << c.layer << "] " << c.name << "\n"
                  << "     path : " << c.path  << "\n"
                  << "     notes: " << c.notes << "\n";
    }

    std::cout << "\n=== END OF MANIFEST ===\n\n";
}

void print_banner()
{
    std::cout
        << "============================================================\n"
        << "  NIFDU — Neural Instant Framework Deployment Universe\n"
        << "  Layers : Serve / Stack / Render / Pack / Droid / Ops / Data\n"
        << "  This build uses C++ + HTML + PowerShell only.\n"
        << "============================================================\n";
}

// ==============================
// 2. Startup Trace
// ==============================

static std::vector<StartupStep> g_startupTrace;
static std::mutex               g_traceMutex;

void trace_startup_step(const std::string& name,
                        const std::string& detail,
                        bool ok)
{
    std::lock_guard<std::mutex> lock(g_traceMutex);
    g_startupTrace.push_back(StartupStep{ name, detail, ok });
}

void dump_startup_trace()
{
    std::lock_guard<std::mutex> lock(g_traceMutex);

    if (g_startupTrace.empty()) {
        std::cout << "\n[NIFDU TRACE] No startup steps recorded.\n";
        return;
    }

    std::cout << "\n=== NIFDU STARTUP TRACE ===\n\n";
    for (const auto& step : g_startupTrace) {
        std::cout << " * " << (step.ok ? "[OK]   " : "[FAIL] ")
                  << step.name << "\n"
                  << "     " << step.detail << "\n";
    }
    std::cout << "\n=== END STARTUP TRACE ===\n\n";
}

} // namespace nifdu
