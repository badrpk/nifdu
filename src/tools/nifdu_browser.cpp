#define _WIN32_WINNT 0x0A00
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#include <windows.h>
#include <winhttp.h>
#include <shellapi.h>

#include <iostream>
#include <string>

// Optional: if you want to log through your engine later,
// you can include nifdu_log.hpp, but not required for now.
// #include "nifdu_log.hpp"

// Simple RAII wrapper to ensure WinHTTP handles are closed.
struct HttpHandles {
    HINTERNET hSession  = nullptr;
    HINTERNET hConnect  = nullptr;
    HINTERNET hRequest  = nullptr;

    ~HttpHandles() {
        if (hRequest)  WinHttpCloseHandle(hRequest);
        if (hConnect)  WinHttpCloseHandle(hConnect);
        if (hSession)  WinHttpCloseHandle(hSession);
    }
};

// Basic GET /health on http://www.nifdu.com
bool send_health_check()
{
    HttpHandles h;
    BOOL  bResult    = FALSE;
    DWORD statusCode = 0;
    DWORD statusSize = sizeof(statusCode);

    // 1) Open WinHTTP session
    h.hSession = WinHttpOpen(
        L"NIFDU Browser/1.0",
        WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,
        WINHTTP_NO_PROXY_NAME,
        WINHTTP_NO_PROXY_BYPASS,
        0);
    if (!h.hSession) {
        std::wcerr << L"[nifdu_browser] WinHttpOpen failed: " << GetLastError() << L"\n";
        return false;
    }

    // 2) Connect to host
    h.hConnect = WinHttpConnect(
        h.hSession,
        L"www.nifdu.com",            // host
        INTERNET_DEFAULT_HTTP_PORT,  // 80
        0);
    if (!h.hConnect) {
        std::wcerr << L"[nifdu_browser] WinHttpConnect failed: " << GetLastError() << L"\n";
        return false;
    }

    // 3) Open request
    h.hRequest = WinHttpOpenRequest(
        h.hConnect,
        L"GET",
        L"/health",
        nullptr,
        WINHTTP_NO_REFERER,
        WINHTTP_DEFAULT_ACCEPT_TYPES,
        0); // plain HTTP, no WINHTTP_FLAG_SECURE
    if (!h.hRequest) {
        std::wcerr << L"[nifdu_browser] WinHttpOpenRequest failed: " << GetLastError() << L"\n";
        return false;
    }

    // 4) Send request
    bResult = WinHttpSendRequest(
        h.hRequest,
        WINHTTP_NO_ADDITIONAL_HEADERS,
        0,
        WINHTTP_NO_REQUEST_DATA,
        0,
        0,
        0);
    if (!bResult) {
        std::wcerr << L"[nifdu_browser] WinHttpSendRequest failed: " << GetLastError() << L"\n";
        return false;
    }

    // 5) Receive response
    bResult = WinHttpReceiveResponse(h.hRequest, nullptr);
    if (!bResult) {
        std::wcerr << L"[nifdu_browser] WinHttpReceiveResponse failed: " << GetLastError() << L"\n";
        return false;
    }

    // 6) Read status code
    if (!WinHttpQueryHeaders(
            h.hRequest,
            WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
            WINHTTP_HEADER_NAME_BY_INDEX,
            &statusCode,
            &statusSize,
            WINHTTP_NO_HEADER_INDEX))
    {
        std::wcerr << L"[nifdu_browser] WinHttpQueryHeaders failed: " << GetLastError() << L"\n";
        return false;
    }

    std::wcerr << L"[nifdu_browser] /health status = " << statusCode << L"\n";
    return (statusCode == 200);
}

int wmain(int argc, wchar_t** argv)
{
    std::wcerr << L"[nifdu_browser] starting..." << std::endl;

    // 1) Optional health ping
    bool ok = send_health_check();
    if (!ok) {
        std::wcerr << L"[nifdu_browser] WARNING: /health did not return 200.\n";
    } else {
        std::wcerr << L"[nifdu_browser] /health OK.\n";
    }

    // 2) Launch AV page in default browser
    std::wstring url = L"http://www.nifdu.com/av.html";
    HINSTANCE hInst = ShellExecuteW(
        nullptr,
        L"open",
        url.c_str(),
        nullptr,
        nullptr,
        SW_SHOWNORMAL);

    if ((INT_PTR)hInst <= 32) {
        std::wcerr << L"[nifdu_browser] ShellExecuteW failed: " << (INT_PTR)hInst << L"\n";
        return 1;
    }

    std::wcerr << L"[nifdu_browser] launched browser to " << url << L"\n";
    return 0;
}
