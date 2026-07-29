param()

$ErrorActionPreference = "Stop"

# =========================
# CONFIG (full paths)
# =========================
$NIFDU_SRC      = "C:\nifdu\src"
$HTTP_CPP       = Join-Path $NIFDU_SRC "nifdu_http_server80.cpp"
$WS_HPP         = Join-Path $NIFDU_SRC "nifdu_ws_session.hpp"
$STUB_HPP       = Join-Path $NIFDU_SRC "nifdu_socket_http_stub.hpp"

$CADDYFILE      = "C:\caddy\Caddyfile"

$NEXT_PORT      = 3000
$NIFDU_PORT     = 8000

function Backup-File {
    param([string]$Path)
    if (!(Test-Path $Path)) { return $null }
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $bak = "$Path.bak_$stamp"
    Copy-Item $Path $bak -Force
    return $bak
}

function Write-TextFileUtf8NoBom {
    param([string]$Path, [string]$Content)
    $dir = Split-Path $Path -Parent
    if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Ensure-Inserted {
    param(
        [string]$Text,
        [string]$Needle,
        [string]$InsertAfterRegex,
        [string]$InsertBlock,
        [string]$What
    )

    if ($Text -like "*$Needle*") {
        Write-Host "[OK] $What already present" -ForegroundColor Green
        return $Text
    }

    $m = [regex]::Match($Text, $InsertAfterRegex, [System.Text.RegularExpressions.RegexOptions]::Multiline)
    if (!$m.Success) { throw "Could not find insertion point for $What using regex: $InsertAfterRegex" }

    $idx = $m.Index + $m.Length
    $before = $Text.Substring(0, $idx)
    $after  = $Text.Substring($idx)
    return ($before + "`r`n" + $InsertBlock + "`r`n" + $after)
}

function Ensure-Inserted-After-FirstOf {
    param(
        [string]$Text,
        [string]$Needle,
        [string[]]$RegexCandidates,
        [string]$InsertBlock,
        [string]$What
    )

    if ($Text -like "*$Needle*") {
        Write-Host "[OK] $What already present" -ForegroundColor Green
        return $Text
    }

    foreach ($rx in $RegexCandidates) {
        $m = [regex]::Match($Text, $rx, [System.Text.RegularExpressions.RegexOptions]::Multiline)
        if ($m.Success) {
            $idx = $m.Index + $m.Length
            $before = $Text.Substring(0, $idx)
            $after  = $Text.Substring($idx)
            Write-Host "[ADD] $What inserted using: $rx" -ForegroundColor Yellow
            return ($before + "`r`n" + $InsertBlock + "`r`n" + $after)
        }
    }

    throw "Could not find insertion point for $What using any candidate regex."
}

# =========================
# 1) CREATE HEADER FILES
# =========================
$wsContent = @"
#pragma once
#include <boost/beast.hpp>
#include <boost/asio.hpp>
#include <memory>
#include <string>

namespace nifdu {

namespace beast     = boost::beast;
namespace http      = beast::http;
namespace websocket = beast::websocket;
namespace asio      = boost::asio;
using tcp           = asio::ip::tcp;

class ws_session : public std::enable_shared_from_this<ws_session> {
public:
    explicit ws_session(tcp::socket&& socket)
        : ws_(std::move(socket)) {}

    void run(http::request<http::string_body>&& req) {
        ws_.set_option(websocket::stream_base::timeout::suggested(beast::role_type::server));
        ws_.set_option(websocket::stream_base::decorator([](websocket::response_type& res) {
            res.set(http::field::server, "NIFDU-http80");
        }));

        ws_.async_accept(req,
            beast::bind_front_handler(&ws_session::on_accept, shared_from_this()));
    }

private:
    websocket::stream<tcp::socket> ws_;
    beast::flat_buffer buffer_;

    void on_accept(beast::error_code ec) {
        if (ec) return;
        do_read();
    }

    void do_read() {
        ws_.async_read(buffer_,
            beast::bind_front_handler(&ws_session::on_read, shared_from_this()));
    }

    void on_read(beast::error_code ec, std::size_t) {
        if (ec == websocket::error::closed) return;
        if (ec) return;

        ws_.text(ws_.got_text());
        ws_.async_write(buffer_.data(),
            beast::bind_front_handler(&ws_session::on_write, shared_from_this()));
    }

    void on_write(beast::error_code ec, std::size_t) {
        if (ec) return;
        buffer_.consume(buffer_.size());
        do_read();
    }
};

} // namespace nifdu
"@

$stubContent = @"
#pragma once
#include <boost/beast.hpp>
#include <string>

namespace nifdu {
namespace beast = boost::beast;
namespace http  = beast::http;

inline http::response<http::string_body>
socket_http_stub(const http::request<http::string_body>& req) {
    http::response<http::string_body> res{http::status::ok, req.version()};
    res.set(http::field::server, "NIFDU-http80");
    res.set(http::field::content_type, "application/json; charset=utf-8");
    res.keep_alive(req.keep_alive());
    res.body() =
        "{"
          "\"status\":\"ok\","
          "\"route\":\"/socket\","
          "\"mode\":\"http_stub\","
          "\"hint\":\"Send WebSocket Upgrade headers to switch to ws\""
        "}";
    res.prepare_payload();
    return res;
}

} // namespace nifdu
"@

Write-Host "`n=== (1) Writing WS header files ===" -ForegroundColor Cyan
if (Test-Path $WS_HPP)   { Write-Host ("Backup: " + (Backup-File $WS_HPP)) -ForegroundColor DarkGray }
Write-TextFileUtf8NoBom $WS_HPP $wsContent
Write-Host "Wrote: C:\nifdu\src\nifdu_ws_session.hpp" -ForegroundColor Green

if (Test-Path $STUB_HPP) { Write-Host ("Backup: " + (Backup-File $STUB_HPP)) -ForegroundColor DarkGray }
Write-TextFileUtf8NoBom $STUB_HPP $stubContent
Write-Host "Wrote: C:\nifdu\src\nifdu_socket_http_stub.hpp" -ForegroundColor Green

# =========================
# 2) PATCH nifdu_http_server80.cpp
# =========================
Write-Host "`n=== (2) Patching C++ server file ===" -ForegroundColor Cyan
if (!(Test-Path $HTTP_CPP)) { throw "Missing: $HTTP_CPP" }

Write-Host ("Backup: " + (Backup-File $HTTP_CPP)) -ForegroundColor DarkGray
$cpp = Get-Content $HTTP_CPP -Raw

$includeBlock = @"
// ===== NIFDU WS PATCH (added) =====
#include "nifdu_ws_session.hpp"
#include "nifdu_socket_http_stub.hpp"
// =================================
"@

$cpp = Ensure-Inserted -Text $cpp -Needle '#include "nifdu_ws_session.hpp"' -InsertAfterRegex '^(?:\s*#include[^\r\n]*\r?\n)+' -InsertBlock $includeBlock -What "WS includes"

$helpersBlock = @"
// ===== NIFDU WS PATCH BEGIN: helpers =====
static inline bool nifdu_is_socket_path(std::string_view target) {
    return (target == "/socket" || target == "/socket/");
}

static inline bool nifdu_is_ws_upgrade(const boost::beast::http::request<boost::beast::http::string_body>& req) {
    return boost::beast::websocket::is_upgrade(req);
}
// ===== NIFDU WS PATCH END: helpers =====
"@

$cpp = Ensure-Inserted -Text $cpp -Needle 'nifdu_is_socket_path' -InsertAfterRegex '^\s*// ===== NIFDU WS PATCH \(added\) =====[\s\S]*?// =================================\s*$' -InsertBlock $helpersBlock -What "WS helpers"

$hookNeedle = "NIFDU WS PATCH BEGIN: /socket hook"

$hookBlock = @"
// ===== NIFDU WS PATCH BEGIN: /socket hook =====
{
    std::string_view t = req.target();
    if (nifdu_is_socket_path(t)) {

        if (nifdu_is_ws_upgrade(req)) {
            auto sock = stream_.release_socket();
            std::make_shared<nifdu::ws_session>(std::move(sock))->run(std::move(req));
            return;
        }

        auto stub = nifdu::socket_http_stub(req);

        auto sp = std::make_shared<decltype(stub)>(std::move(stub));
        boost::beast::http::async_write(stream_, *sp,
            [self = shared_from_this(), sp](boost::beast::error_code ec, std::size_t) {
                if (ec) return;
                if (!sp->keep_alive()) {
                    boost::beast::error_code ec2;
                    self->stream_.socket().shutdown(boost::asio::ip::tcp::socket::shutdown_send, ec2);
                    return;
                }
                self->do_read();
            });

        return;
    }
}
// ===== NIFDU WS PATCH END: /socket hook =====
"@

$targetRegexCandidates = @(
    '^\s*auto\s+target\s*=\s*req\.target\(\)\s*;\s*$',
    '^\s*std::string_view\s+target\s*=\s*req\.target\(\)\s*;\s*$',
    '^\s*std::string\s+target\s*=\s*std::string\s*\(\s*req\.target\(\)\s*\)\s*;\s*$',
    '^\s*std::string\s+target\s*\(\s*req\.target\(\)\s*\)\s*;\s*$'
)

$cpp = Ensure-Inserted-After-FirstOf -Text $cpp -Needle $hookNeedle -RegexCandidates $targetRegexCandidates -InsertBlock $hookBlock -What "/socket WS hook"

Write-TextFileUtf8NoBom $HTTP_CPP $cpp
Write-Host "Patched: C:\nifdu\src\nifdu_http_server80.cpp" -ForegroundColor Green

# =========================
# 3) PATCH CADDYFILE (Option A)
# =========================
Write-Host "`n=== (3) Patching Caddyfile ===" -ForegroundColor Cyan
if (!(Test-Path $CADDYFILE)) {
    Write-Host "[SKIP] Missing C:\caddy\Caddyfile" -ForegroundColor Yellow
} else {
    Write-Host ("Backup: " + (Backup-File $CADDYFILE)) -ForegroundColor DarkGray
    $cf = Get-Content $CADDYFILE -Raw

    if ($cf -match '(?m)^\s*@ws\s+path\s+/socket\*') {
        Write-Host "[OK] Caddyfile already has @ws /socket* rule" -ForegroundColor Green
    } else {
        $siteRx = '(?ms)(sophyane\.com\s*,\s*www\.sophyane\.com\s*\{\s*)'
        $m = [regex]::Match($cf, $siteRx)
        if (!$m.Success) { throw "Could not find sophyane.com site block label: sophyane.com, www.sophyane.com {" }

        $insert = @"
    # ===== NIFDU / SOPHYANE ROUTING (WS + API) =====
    @ws path /socket*
    handle @ws {
        reverse_proxy 127.0.0.1:$NEXT_PORT
    }

    @api path /api/*
    handle @api {
        reverse_proxy 127.0.0.1:$NIFDU_PORT
    }

    handle {
        reverse_proxy 127.0.0.1:$NEXT_PORT
    }
    # ==============================================
"@

        $cf = [regex]::Replace($cf, $siteRx, ('$1' + $insert), 1)
        Write-TextFileUtf8NoBom $CADDYFILE $cf
        Write-Host "[ADD] Inserted WS/API routing into Caddyfile" -ForegroundColor Yellow
    }
}

Write-Host "`nDONE." -ForegroundColor Green
