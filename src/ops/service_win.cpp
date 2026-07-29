#include <boost/asio.hpp>

#ifdef _WIN32
  #ifndef WIN32_LEAN_AND_MEAN
  #define WIN32_LEAN_AND_MEAN
  #endif
  #include <windows.h>
#endif

#include <string>
#include <atomic>
#include <iostream>

namespace net = boost::asio;

using ServerRunFunc = int(*)(const std::string&, std::atomic<bool>&, net::io_context&);

static SERVICE_STATUS_HANDLE    g_status_handle = NULL;
static SERVICE_STATUS           g_service_status = {0};
static std::atomic<bool>* g_stop_flag = nullptr;
static net::io_context* g_ioc = nullptr;
static std::string              g_config_path;
static ServerRunFunc            g_server_run_func = nullptr;

static char                     g_service_name[256] = "nifdu-http-8077";

void ReportSvcStatus(DWORD dwCurrentState, DWORD dwWin32ExitCode, DWORD dwWaitHint) {
    static DWORD dwCheckPoint = 1;
    g_service_status.dwCurrentState = dwCurrentState;
    g_service_status.dwWin32ExitCode = dwWin32ExitCode;
    g_service_status.dwWaitHint = dwWaitHint;
    g_service_status.dwControlsAccepted = (dwCurrentState == SERVICE_START_PENDING) ? 0 : (SERVICE_ACCEPT_STOP | SERVICE_ACCEPT_SHUTDOWN);
    g_service_status.dwCheckPoint = ((dwCurrentState == SERVICE_RUNNING) || (dwCurrentState == SERVICE_STOPPED)) ? 0 : dwCheckPoint++;
    SetServiceStatus(g_status_handle, &g_service_status);
}

VOID WINAPI ServiceCtrlHandler(DWORD dwCtrl) {
    switch (dwCtrl) {
        case SERVICE_CONTROL_STOP:
        case SERVICE_CONTROL_SHUTDOWN:
            ReportSvcStatus(SERVICE_STOP_PENDING, NO_ERROR, 0);
            std::cout << "[NIFDU Service] Stop signal received.\n";
            if (g_stop_flag) {
                g_stop_flag->store(true);
            }
            if (g_ioc) {
                net::post(*g_ioc, [&]() { g_ioc->stop(); });
            }
            break;
    }
}

VOID WINAPI ServiceMain(DWORD, LPTSTR*) {
    g_status_handle = RegisterServiceCtrlHandler(g_service_name, ServiceCtrlHandler);
    if (!g_status_handle) {
         std::cerr << "RegisterServiceCtrlHandler failed. Error: " << GetLastError() << "\n";
         return;
    }

    g_service_status.dwServiceType = SERVICE_WIN32_OWN_PROCESS;
    g_service_status.dwServiceSpecificExitCode = 0;

    ReportSvcStatus(SERVICE_START_PENDING, NO_ERROR, 3000);

    std::atomic<bool> stop_flag{false};
    net::io_context ioc(static_cast<int>(std::max(1u, std::thread::hardware_concurrency())));

    g_stop_flag = &stop_flag;
    g_ioc = &ioc;

    ReportSvcStatus(SERVICE_RUNNING, NO_ERROR, 0);
    std::cout << "[NIFDU Service] Service is running.\n";

    if (g_server_run_func) {
        g_server_run_func(g_config_path, *g_stop_flag, *g_ioc);
    }

    std::cout << "[NIFDU Service] Server function returned, service stopping.\n";
    ReportSvcStatus(SERVICE_STOPPED, NO_ERROR, 0);
}

extern "C" int nifdu_service_entry(int argc, char** argv, ServerRunFunc run_func) {
    g_server_run_func = run_func;
    
    for (int i = 1; i + 1 < argc; ++i) {
        if (std::string(argv[i]) == "--config") {
            g_config_path = argv[i + 1];
            break;
        }
    }
    if (g_config_path.empty()) {
        g_config_path = "config/nifdu.toml"; // Default
    }

    SERVICE_TABLE_ENTRY DispatchTable[] = {
        { g_service_name, (LPSERVICE_MAIN_FUNCTION)ServiceMain },
        { NULL, NULL }
    };

    if (!StartServiceCtrlDispatcher(DispatchTable)) {
        std::cerr << "StartServiceCtrlDispatcherA failed. Error: " << GetLastError() << "\n";
    }
    return 0;
}
