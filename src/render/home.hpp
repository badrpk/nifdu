// src/render/home.hpp
#pragma once

#include <string>
#include "render/context.hpp"
#include "render/cache.hpp"

namespace nifdu::render {

// Hot path for GET / on nifdu.com / www.nifdu.com.
inline std::string render_home(const RenderContext& ctx)
{
    // 1) First try AI-generated cached HTML (if any)
    (void)ctx;
    {
        std::string cached = load_home_html();
        if (!cached.empty()) {
            return cached;
        }
    }

    // 2) Fallback: static built-in HTML (your current dark theme)
    std::string html;
    html.reserve(4096);

    html += "<!DOCTYPE html><html lang=\"en\"><head>";
    html += "<meta charset=\"utf-8\">";
    html += "<title>NIFDU Superapp Host</title>";
    html += "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">";
    html += "<style>";
    html += "*,*::before,*::after{box-sizing:border-box;}";
    html += "html,body{margin:0;padding:0;height:100%;}";
    html += "body{font-family:system-ui,-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;";
    html += "background:#020617;color:#e5e7eb;display:flex;flex-direction:column;";
    html += "align-items:center;}";
    html += ".wrap{flex:1;display:flex;flex-direction:column;align-items:center;";
    html += "justify-content:center;padding:16px;width:100%;max-width:960px;margin:0 auto;}";
    html += ".card{background:#020617;border-radius:16px;border:1px solid #1f2937;";
    html += "padding:20px;margin-bottom:16px;width:100%;}";
    html += "h1{font-size:1.75rem;margin:0 0 8px 0;}";
    html += "h2{font-size:1.2rem;margin:0 0 6px 0;}";
    html += "p{margin:4px 0;line-height:1.4;}";
    html += "code{background:#020617;border-radius:6px;padding:2px 6px;font-size:0.9rem;}";
    html += "@media (max-width:640px){.card{padding:16px;}}";
    html += "</style>";
    html += "</head><body>";
    html += "<div class=\"wrap\">";
    html += "<div class=\"card\">";
    html += "<h1>NIFDU Superapp Host</h1>";
    html += "<p>Welcome to <strong>nifdu.com</strong>. This page is rendered directly in C++ for maximum performance.</p>";
    html += "</div>";
    html += "<div class=\"card\">";
    html += "<h2>AI Console</h2>";
    html += "<p>Use <code>/api/chat</code> with <code>{ &quot;backend&quot;: &quot;qwen&quot; }</code> or <code>&quot;openai&quot;</code> to talk to your AI engine.</p>";
    html += "<p>The layout here can be evolved by your AI pipeline; the runtime path stays pure C++.</p>";
    html += "</div>";
    html += "</div>";
    html += "</body></html>";

    return html;
}

} // namespace nifdu::render
