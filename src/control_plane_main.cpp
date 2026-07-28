#include <nlohmann/json.hpp>

#include <algorithm>
#include <chrono>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <map>
#include <queue>
#include <regex>
#include <set>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

#if defined(__unix__) || defined(__APPLE__)
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#endif

using json = nlohmann::json;
namespace fs = std::filesystem;

namespace {

struct ControlGraph {
    std::map<std::string, std::vector<std::string>> edges;
    std::map<std::string, std::vector<std::string>> permissions;
};

std::string trim(std::string value) {
    const auto first = value.find_first_not_of(" \t\r\n");
    if (first == std::string::npos) {
        return "";
    }
    const auto last = value.find_last_not_of(" \t\r\n");
    return value.substr(first, last - first + 1);
}

std::string lower(std::string value) {
    std::transform(
        value.begin(), value.end(), value.begin(),
        [](unsigned char c) { return static_cast<char>(std::tolower(c)); }
    );
    return value;
}

std::string join_arguments(int argc, char* argv[], int start) {
    std::ostringstream output;
    for (int i = start; i < argc; ++i) {
        if (i > start) {
            output << ' ';
        }
        output << argv[i];
    }
    return trim(output.str());
}

std::string timestamp_utc() {
    const auto now = std::chrono::system_clock::now();
    const std::time_t current = std::chrono::system_clock::to_time_t(now);
    std::tm utc{};
#if defined(_WIN32)
    gmtime_s(&utc, &current);
#else
    gmtime_r(&current, &utc);
#endif
    std::ostringstream output;
    output << std::put_time(&utc, "%Y%m%dT%H%M%SZ");
    return output.str();
}

ControlGraph default_graph() {
    ControlGraph graph;
    graph.edges = {
        {"user_task", {"policy_gate"}},
        {"policy_gate", {"planner"}},
        {"planner", {"builder"}},
        {"builder", {"validator"}},
        {"validator", {"builder", "judge"}},
        {"judge", {"builder", "preview", "final"}},
        {"preview", {"final"}}
    };
    graph.permissions = {
        {"policy_gate", {"allow", "deny"}},
        {"planner", {"analyse", "plan"}},
        {"builder", {"create_product", "repair_product"}},
        {"validator", {"inspect_html", "check_requirements"}},
        {"judge", {"score", "accept", "reject"}},
        {"preview", {"serve_localhost", "open_browser"}},
        {"final", {"report"}}
    };
    return graph;
}

std::vector<std::string> shortest_path(
    const ControlGraph& graph,
    const std::string& start,
    const std::string& goal
) {
    std::queue<std::vector<std::string>> pending;
    std::set<std::string> visited;
    pending.push({start});
    visited.insert(start);

    while (!pending.empty()) {
        auto path = pending.front();
        pending.pop();
        const std::string node = path.back();

        if (node == goal) {
            return path;
        }

        const auto found = graph.edges.find(node);
        if (found == graph.edges.end()) {
            continue;
        }

        for (const std::string& next : found->second) {
            if (visited.insert(next).second) {
                auto candidate = path;
                candidate.push_back(next);
                pending.push(std::move(candidate));
            }
        }
    }

    throw std::runtime_error("No authorised graph path from " + start + " to " + goal);
}

std::vector<std::string> policy_violations(const std::string& task) {
    const std::string text = lower(task);
    const std::vector<std::string> blocked = {
        "rm -rf /",
        "rm -rf /*",
        "mkfs",
        "wipe device",
        "delete all files",
        "dd if=/dev/zero of=/dev",
        "chmod -r 777 /",
        "curl | sh",
        "wget | sh"
    };

    std::vector<std::string> violations;
    for (const std::string& pattern : blocked) {
        if (text.find(pattern) != std::string::npos) {
            violations.push_back("Blocked operation: " + pattern);
        }
    }

    const std::vector<std::regex> destructive = {
        std::regex(R"(\brm\s+-[a-z]*r[a-z]*f\b.*(?:/|~|\$home))", std::regex::icase),
        std::regex(R"(\b(?:erase|wipe|destroy)\b.*\b(?:disk|system|device|filesystem)\b)", std::regex::icase),
        std::regex(R"(\b(?:steal|exfiltrate)\b.*\b(?:password|token|key|credential)\b)", std::regex::icase)
    };

    for (const auto& pattern : destructive) {
        if (std::regex_search(task, pattern)) {
            violations.push_back("Potentially destructive or credential-exfiltration request");
            break;
        }
    }

    return violations;
}

std::string join_path(const std::vector<std::string>& path) {
    std::ostringstream output;
    for (std::size_t i = 0; i < path.size(); ++i) {
        if (i != 0) {
            output << " -> ";
        }
        output << path[i];
    }
    return output.str();
}

std::string controlled_prompt(
    const std::string& task,
    const std::vector<std::string>& path
) {
    std::ostringstream prompt;
    prompt
        << "GRAPH CONTROL PLANE MODE IS MANDATORY.\n"
        << "Original customer request:\n" << task << "\n\n"
        << "Authorised control path:\n" << join_path(path) << "\n\n"
        << "Execution contract:\n"
        << "1. Treat the customer request as immutable.\n"
        << "2. Plan before building.\n"
        << "3. Build only the requested product.\n"
        << "4. Validate syntax, required interactions, mobile behaviour, accessibility and error states before judging.\n"
        << "5. The judge may accept only with score >= 95, zero critical issues and zero unmet requirements.\n"
        << "6. On validation or judge failure, repair and return through the authorised builder path.\n"
        << "7. Do not invent evidence, tests, files, controls or results.\n"
        << "8. Preview is an authorised stage only after the final judge decision.\n"
        << "9. Include graph-path evidence and the final decision in the generated evaluation report.\n"
        << "10. Never bypass policy_gate, validator or judge.\n\n"
        << "Now execute the original customer request.";
    return prompt.str();
}

fs::path executable_directory(char* argv0) {
#if defined(__linux__)
    std::error_code error;
    const fs::path resolved = fs::read_symlink("/proc/self/exe", error);
    if (!error && !resolved.empty()) {
        return resolved.parent_path();
    }
#endif
    return fs::absolute(fs::path(argv0)).parent_path();
}

fs::path trace_directory() {
    const char* home = std::getenv("HOME");
    if (!home || !*home) {
        throw std::runtime_error("HOME is not set");
    }
    return fs::path(home) / ".local" / "share" / "nifdu" / "control-plane" / "traces";
}

fs::path write_trace(
    const std::string& task,
    const std::vector<std::string>& path,
    const std::vector<std::string>& violations,
    const std::string& status,
    int exit_code = -1
) {
    const fs::path directory = trace_directory();
    fs::create_directories(directory);
    const fs::path file = directory / (timestamp_utc() + "-trace.json");

    json document = {
        {"version", "1.0"},
        {"status", status},
        {"task", task},
        {"authorised_path", path},
        {"violations", violations},
        {"acceptance_score", 95},
        {"exit_code", exit_code}
    };

    std::ofstream output(file, std::ios::binary | std::ios::trunc);
    if (!output) {
        throw std::runtime_error("Unable to write graph trace: " + file.string());
    }
    output << document.dump(2) << '\n';
    return file;
}

int execute_core(
    const fs::path& core,
    const std::string& prompt,
    const fs::path& trace
) {
#if defined(__unix__) || defined(__APPLE__)
    const pid_t child = fork();
    if (child < 0) {
        throw std::runtime_error("Unable to fork NIFDU core process");
    }

    if (child == 0) {
        setenv("NIFDU_GRAPH_CONTROL_PLANE", "1", 1);
        setenv("NIFDU_GRAPH_TRACE", trace.c_str(), 1);
        const std::string core_text = core.string();
        char* const arguments[] = {
            const_cast<char*>(core_text.c_str()),
            const_cast<char*>("build"),
            const_cast<char*>(prompt.c_str()),
            nullptr
        };
        execv(core_text.c_str(), arguments);
        std::cerr << "Unable to execute " << core_text << '\n';
        _exit(127);
    }

    int status = 0;
    if (waitpid(child, &status, 0) < 0) {
        throw std::runtime_error("Unable to wait for NIFDU core process");
    }
    if (WIFEXITED(status)) {
        return WEXITSTATUS(status);
    }
    if (WIFSIGNALED(status)) {
        return 128 + WTERMSIG(status);
    }
    return EXIT_FAILURE;
#else
    throw std::runtime_error("The graph-control entrypoint currently requires a Unix-like platform");
#endif
}

void print_status(const fs::path& core) {
    std::cout
        << "NIFDU native C++ graph control plane: enabled\n"
        << "Core executable: " << core << "\n"
        << "Graph: user_task -> policy_gate -> planner -> builder -> validator -> judge -> preview/final\n"
        << "Acceptance threshold: 95/100\n"
        << "Trace directory: " << trace_directory() << "\n";
}

void print_usage() {
    std::cout
        << "NIFDU C++ Graph-Controlled Product Builder\n\n"
        << "Usage:\n"
        << "  nifdu \"customer request\"\n"
        << "  nifdu build \"customer request\"\n"
        << "  nifdu --graph-status\n"
        << "  nifdu --raw [core arguments]\n";
}

} // namespace

int main(int argc, char* argv[]) {
    try {
        const fs::path core = executable_directory(argv[0]) / "nifdu-core";

        if (argc < 2) {
            print_usage();
            return EXIT_SUCCESS;
        }

        const std::string first = argv[1];
        if (first == "--graph-status") {
            print_status(core);
            return EXIT_SUCCESS;
        }

#if defined(__unix__) || defined(__APPLE__)
        if (first == "--raw") {
            if (!fs::exists(core)) {
                throw std::runtime_error("NIFDU core executable was not found: " + core.string());
            }
            std::vector<char*> arguments;
            const std::string core_text = core.string();
            arguments.push_back(const_cast<char*>(core_text.c_str()));
            for (int i = 2; i < argc; ++i) {
                arguments.push_back(argv[i]);
            }
            arguments.push_back(nullptr);
            execv(core_text.c_str(), arguments.data());
            throw std::runtime_error("Unable to execute raw NIFDU core");
        }
#endif

        int prompt_start = 1;
        if (first == "build" || first == "create") {
            prompt_start = 2;
        }
        if (argc <= prompt_start) {
            print_usage();
            return EXIT_FAILURE;
        }

        const std::string task = join_arguments(argc, argv, prompt_start);
        const ControlGraph graph = default_graph();
        const auto violations = policy_violations(task);

        if (!violations.empty()) {
            const fs::path trace = write_trace(
                task,
                {"user_task", "policy_gate"},
                violations,
                "DENIED",
                3
            );
            std::cerr << "GRAPH CONTROL PLANE: DENIED\n";
            for (const auto& violation : violations) {
                std::cerr << " - " << violation << '\n';
            }
            std::cerr << "Trace: " << trace << '\n';
            return 3;
        }

        const auto path = shortest_path(graph, "user_task", "final");
        const std::string prompt = controlled_prompt(task, path);
        const fs::path trace = write_trace(task, path, {}, "AUTHORISED");

        if (!fs::exists(core)) {
            throw std::runtime_error("NIFDU core executable was not found: " + core.string());
        }

        std::cout
            << "GRAPH CONTROL PLANE: AUTHORISED\n"
            << "Path: " << join_path(path) << "\n"
            << "Trace: " << trace << "\n\n";

        const int exit_code = execute_core(core, prompt, trace);
        write_trace(task, path, {}, exit_code == 0 ? "COMPLETED" : "CORE_FAILED", exit_code);
        return exit_code;
    } catch (const std::exception& error) {
        std::cerr << "NIFDU control-plane fatal error: " << error.what() << '\n';
        return EXIT_FAILURE;
    }
}
