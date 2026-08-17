#include <curl/curl.h>
#include <nlohmann/json.hpp>

#include <algorithm>
#include <atomic>
#include <chrono>
#include <csignal>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <map>
#include <optional>
#include <regex>
#include <set>
#include <sstream>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>

#if defined(__unix__) || defined(__APPLE__)
#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#endif

using json = nlohmann::json;
namespace fs = std::filesystem;

namespace {

constexpr long CONNECT_TIMEOUT_SECONDS = 30;
constexpr long REQUEST_TIMEOUT_SECONDS = 120;
constexpr int MAX_ITERATIONS = 10;
constexpr int ACCEPTANCE_SCORE = 95;
int g_server_port = 0;
constexpr std::size_t MAX_JUDGE_IMAGES = 18;

struct HttpResponse {
    CURLcode curl_code = CURLE_OK;
    long status = 0;
    std::string body;
    std::string error;
};

struct Capture {
    std::string route;
    std::string viewport;
    std::string kind;
    fs::path path;
};

struct Evaluation {
    bool accepted = false;
    int score = 0;
    int critical_issues = 0;
    int unmet_requirements = 0;
    std::string summary;
    json raw;
};

std::string env(
    const char* name,
    const std::string& fallback = ""
) {
    const char* value = std::getenv(name);

    return value && *value
        ? std::string(value)
        : fallback;
}

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
        value.begin(),
        value.end(),
        value.begin(),
        [](unsigned char character) {
            return static_cast<char>(
                std::tolower(character)
            );
        }
    );

    return value;
}

std::string shell_quote(const std::string& value) {
    std::string quoted = "'";

    for (char character : value) {
        if (character == '\'') {
            quoted += "'\\''";
        } else {
            quoted += character;
        }
    }

    quoted += '\'';
    return quoted;
}

std::string timestamp() {
    const auto now = std::chrono::system_clock::now();
    const std::time_t time =
        std::chrono::system_clock::to_time_t(now);

    std::tm local{};

#if defined(_WIN32)
    localtime_s(&local, &time);
#else
    localtime_r(&time, &local);
#endif

    std::ostringstream output;

    output << std::put_time(
        &local,
        "%Y%m%d-%H%M%S"
    );

    return output.str();
}

std::string read_file(const fs::path& path) {
    std::ifstream input(path, std::ios::binary);

    if (!input) {
        throw std::runtime_error(
            "Unable to read file: " + path.string()
        );
    }

    std::ostringstream output;
    output << input.rdbuf();

    return output.str();
}

void write_file(
    const fs::path& path,
    const std::string& content
) {
    fs::create_directories(path.parent_path());

    std::ofstream output(
        path,
        std::ios::binary | std::ios::trunc
    );

    if (!output) {
        throw std::runtime_error(
            "Unable to write file: " + path.string()
        );
    }

    output << content;
}

bool command_exists(const std::string& command) {
    const std::string check =
        "command -v " + shell_quote(command) +
        " >/dev/null 2>&1";

    return std::system(check.c_str()) == 0;
}

std::string find_chromium() {
    const std::vector<std::string> candidates = {
        env("NIFDU_CHROMIUM"),
        "chromium",
        "chromium-browser",
        "google-chrome",
        "google-chrome-stable"
    };

    for (const std::string& candidate : candidates) {
        if (
            !candidate.empty() &&
            command_exists(candidate)
        ) {
            return candidate;
        }
    }

    throw std::runtime_error(
        "Chromium was not found. Install it with: "
        "sudo apt-get install -y chromium"
    );
}

std::size_t write_callback(
    char* data,
    std::size_t size,
    std::size_t count,
    void* destination
) {
    const std::size_t bytes = size * count;

    static_cast<std::string*>(destination)->append(
        data,
        bytes
    );

    return bytes;
}

HttpResponse post_json(
    const std::string& url,
    const std::string& api_key,
    const std::string& body
) {
    CURL* curl = curl_easy_init();

    if (!curl) {
        throw std::runtime_error(
            "curl_easy_init failed"
        );
    }

    HttpResponse response;
    curl_slist* headers = nullptr;
    char error_buffer[CURL_ERROR_SIZE] = {};

    headers = curl_slist_append(
        headers,
        "Content-Type: application/json"
    );

    const std::string api_header =
        "x-goog-api-key: " + api_key;

    headers = curl_slist_append(
        headers,
        api_header.c_str()
    );

    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl, CURLOPT_POST, 1L);
    curl_easy_setopt(
        curl,
        CURLOPT_POSTFIELDS,
        body.c_str()
    );
    curl_easy_setopt(
        curl,
        CURLOPT_POSTFIELDSIZE_LARGE,
        static_cast<curl_off_t>(body.size())
    );
    curl_easy_setopt(
        curl,
        CURLOPT_WRITEFUNCTION,
        write_callback
    );
    curl_easy_setopt(
        curl,
        CURLOPT_WRITEDATA,
        &response.body
    );
    curl_easy_setopt(
        curl,
        CURLOPT_ERRORBUFFER,
        error_buffer
    );
    curl_easy_setopt(
        curl,
        CURLOPT_CONNECTTIMEOUT,
        CONNECT_TIMEOUT_SECONDS
    );
    curl_easy_setopt(
        curl,
        CURLOPT_TIMEOUT,
        REQUEST_TIMEOUT_SECONDS
    );
    curl_easy_setopt(
        curl,
        CURLOPT_FOLLOWLOCATION,
        1L
    );
    curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1L);
    curl_easy_setopt(
        curl,
        CURLOPT_USERAGENT,
        "nifdu-visual-supervisor/2.0"
    );

    response.curl_code = curl_easy_perform(curl);

    curl_easy_getinfo(
        curl,
        CURLINFO_RESPONSE_CODE,
        &response.status
    );

    if (error_buffer[0] != '\0') {
        response.error = error_buffer;
    } else if (response.curl_code != CURLE_OK) {
        response.error =
            curl_easy_strerror(response.curl_code);
    }

    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);

    return response;
}

std::string response_error(
    const HttpResponse& response
) {
    if (!response.error.empty()) {
        return response.error;
    }

    try {
        const json data = json::parse(response.body);

        if (
            data.contains("error") &&
            data["error"].is_object()
        ) {
            return data["error"].value(
                "message",
                response.body
            );
        }
    } catch (...) {
    }

    if (response.body.empty()) {
        return "HTTP " +
            std::to_string(response.status);
    }

    return response.body.substr(0, 2000);
}

std::string strip_markdown_fence(
    std::string content
) {
    content = trim(content);

    if (content.rfind("```", 0) != 0) {
        return content;
    }

    const auto first_newline =
        content.find('\n');

    const auto last_fence =
        content.rfind("```");

    if (
        first_newline == std::string::npos ||
        last_fence == std::string::npos ||
        last_fence <= first_newline
    ) {
        return content;
    }

    return trim(
        content.substr(
            first_newline + 1,
            last_fence - first_newline - 1
        )
    );
}

std::string extract_gemini_text(
    const HttpResponse& response
) {
    if (
        response.curl_code != CURLE_OK ||
        response.status < 200 ||
        response.status >= 300
    ) {
        throw std::runtime_error(
            "Gemini request failed: " +
            response_error(response)
        );
    }

    const json data = json::parse(response.body);

    if (
        !data.contains("candidates") ||
        !data["candidates"].is_array() ||
        data["candidates"].empty()
    ) {
        throw std::runtime_error(
            "Gemini returned no candidates: " +
            data.dump()
        );
    }

    const json& candidate = data["candidates"][0];

    if (
        !candidate.contains("content") ||
        !candidate["content"].contains("parts")
    ) {
        throw std::runtime_error(
            "Gemini candidate has no content parts"
        );
    }

    std::string output;

    for (
        const json& part :
        candidate["content"]["parts"]
    ) {
        if (
            part.is_object() &&
            part.contains("text")
        ) {
            output += part["text"].get<std::string>();
        }
    }

    if (trim(output).empty()) {
        throw std::runtime_error(
            "Gemini returned empty text"
        );
    }

    return output;
}

std::string base64_encode(
    const std::vector<unsigned char>& input
) {
    static constexpr char table[] =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        "abcdefghijklmnopqrstuvwxyz"
        "0123456789+/";

    std::string output;
    output.reserve(
        ((input.size() + 2) / 3) * 4
    );

    std::size_t index = 0;

    while (index + 2 < input.size()) {
        const unsigned value =
            (static_cast<unsigned>(input[index]) << 16U) |
            (static_cast<unsigned>(input[index + 1]) << 8U) |
            static_cast<unsigned>(input[index + 2]);

        output.push_back(table[(value >> 18U) & 0x3FU]);
        output.push_back(table[(value >> 12U) & 0x3FU]);
        output.push_back(table[(value >> 6U) & 0x3FU]);
        output.push_back(table[value & 0x3FU]);

        index += 3;
    }

    if (index < input.size()) {
        unsigned value =
            static_cast<unsigned>(input[index]) << 16U;

        output.push_back(table[(value >> 18U) & 0x3FU]);

        if (index + 1 < input.size()) {
            value |=
                static_cast<unsigned>(
                    input[index + 1]
                ) << 8U;

            output.push_back(
                table[(value >> 12U) & 0x3FU]
            );
            output.push_back(
                table[(value >> 6U) & 0x3FU]
            );
            output.push_back('=');
        } else {
            output.push_back(
                table[(value >> 12U) & 0x3FU]
            );
            output.push_back('=');
            output.push_back('=');
        }
    }

    return output;
}

std::string base64_file(const fs::path& path) {
    std::ifstream input(path, std::ios::binary);

    if (!input) {
        throw std::runtime_error(
            "Unable to open image: " + path.string()
        );
    }

    const std::vector<unsigned char> bytes{
        std::istreambuf_iterator<char>(input),
        std::istreambuf_iterator<char>()
    };

    return base64_encode(bytes);
}

std::string mime_type(const fs::path& path) {
    const std::string extension =
        lower(path.extension().string());

    if (extension == ".jpg" || extension == ".jpeg") {
        return "image/jpeg";
    }

    if (extension == ".webp") {
        return "image/webp";
    }

    return "image/png";
}

class GeminiClient {
public:
    GeminiClient(
        std::string api_key,
        std::string builder_model,
        std::string judge_model
    )
        : api_key_(std::move(api_key)),
          builder_model_(std::move(builder_model)),
          judge_model_(std::move(judge_model)) {}

    std::string build_initial(
        const std::string& requirement
    ) const {
        const std::string instruction =
            "Act as the senior product engineering builder.\n"
            "Create one complete production-quality web product "
            "that satisfies the immutable customer request below.\n"
            "Return only a complete index.html document.\n"
            "Embed all CSS and JavaScript in the document.\n"
            "Do not use Markdown fences or explanations.\n"
            "Use semantic HTML, responsive layouts, accessible "
            "controls, polished states and professional content.\n"
            "All interactions must work without a backend.\n\n"
            "IMMUTABLE CUSTOMER REQUEST:\n" +
            requirement;

        return strip_markdown_fence(
            generate_text(
                builder_model_,
                instruction,
                0.7
            )
        );
    }

    Evaluation judge(
        const std::string& requirement,
        const std::string& html,
        const std::vector<Capture>& captures,
        int iteration
    ) const {
        json parts = json::array();

        std::ostringstream prompt;

        prompt
            << "You are NIFDU's independent visual product judge.\n"
            << "Do not praise weak work. Inspect every supplied image.\n"
            << "Judge the rendered product against every explicit "
            << "customer requirement and against a demanding "
            << "global-quality heuristic comparable to leading "
            << "commercial products.\n\n"
            << "Iteration: " << iteration << " of "
            << MAX_ITERATIONS << "\n\n"
            << "IMMUTABLE CUSTOMER REQUEST:\n"
            << requirement << "\n\n"
            << "GLOBAL QUALITY RUBRIC:\n"
            << "- requirement completeness\n"
            << "- information architecture\n"
            << "- desktop visual polish\n"
            << "- mobile visual polish\n"
            << "- typography and spacing\n"
            << "- content quality\n"
            << "- interaction clarity\n"
            << "- accessibility\n"
            << "- credibility and trust\n"
            << "- empty/loading/error states\n"
            << "- responsive consistency\n"
            << "- originality and commercial readiness\n\n"
            << "Return JSON only with this exact structure:\n"
            << "{\n"
            << "  \"accepted\": false,\n"
            << "  \"score\": 0,\n"
            << "  \"critical_issues\": 0,\n"
            << "  \"unmet_requirements\": 0,\n"
            << "  \"summary\": \"...\",\n"
            << "  \"requirement_checks\": [\n"
            << "    {\"requirement\":\"...\","
            << "\"passed\":false,\"evidence\":\"...\","
            << "\"required_change\":\"...\"}\n"
            << "  ],\n"
            << "  \"visual_issues\": [\"...\"],\n"
            << "  \"mobile_issues\": [\"...\"],\n"
            << "  \"interaction_issues\": [\"...\"],\n"
            << "  \"accessibility_issues\": [\"...\"],\n"
            << "  \"required_changes\": [\"...\"]\n"
            << "}\n\n"
            << "Acceptance is permitted only when score >= "
            << ACCEPTANCE_SCORE
            << ", critical_issues is 0, unmet_requirements is 0, "
            << "and every explicit requirement is visibly met.\n\n"
            << "CURRENT HTML SOURCE:\n"
            << html.substr(0, 60000);

        parts.push_back({
            {"text", prompt.str()}
        });

        std::size_t image_count = 0;

        for (const Capture& capture : captures) {
            if (
                image_count >= MAX_JUDGE_IMAGES ||
                !fs::exists(capture.path)
            ) {
                break;
            }

            parts.push_back({
                {
                    "text",
                    "Screenshot evidence: route=" +
                    capture.route +
                    ", viewport=" +
                    capture.viewport +
                    ", kind=" +
                    capture.kind
                }
            });

            parts.push_back({
                {
                    "inline_data",
                    {
                        {
                            "mime_type",
                            mime_type(capture.path)
                        },
                        {
                            "data",
                            base64_file(capture.path)
                        }
                    }
                }
            });

            ++image_count;
        }

        const json request_body = {
            {
                "contents",
                json::array({
                    {
                        {"role", "user"},
                        {"parts", parts}
                    }
                })
            },
            {
                "generationConfig",
                {
                    {"temperature", 0.1},
                    {"responseMimeType", "application/json"}
                }
            }
        };

        const HttpResponse response = post_json(
            endpoint(judge_model_),
            api_key_,
            request_body.dump()
        );

        const std::string result_text =
            strip_markdown_fence(
                extract_gemini_text(response)
            );

        const json result = json::parse(result_text);

        Evaluation evaluation;
        evaluation.raw = result;
        evaluation.score =
            result.value("score", 0);
        evaluation.critical_issues =
            result.value("critical_issues", 1);
        evaluation.unmet_requirements =
            result.value("unmet_requirements", 1);
        evaluation.summary =
            result.value("summary", "");

        const bool model_accepted =
            result.value("accepted", false);

        evaluation.accepted =
            model_accepted &&
            evaluation.score >= ACCEPTANCE_SCORE &&
            evaluation.critical_issues == 0 &&
            evaluation.unmet_requirements == 0;

        return evaluation;
    }

    std::string repair(
        const std::string& requirement,
        const std::string& current_html,
        const Evaluation& evaluation,
        int iteration
    ) const {
        std::ostringstream instruction;

        instruction
            << "Act as NIFDU's senior corrective product engineer.\n"
            << "Repair the current web product using every finding "
            << "from the independent visual judge.\n"
            << "The original customer request is immutable.\n"
            << "Do not remove working functionality merely to make "
            << "the page simpler.\n"
            << "Return only the complete revised index.html.\n"
            << "Do not return Markdown or explanations.\n"
            << "This is repair iteration "
            << iteration << " of "
            << MAX_ITERATIONS << ".\n\n"
            << "IMMUTABLE CUSTOMER REQUEST:\n"
            << requirement << "\n\n"
            << "JUDGE REPORT:\n"
            << evaluation.raw.dump(2) << "\n\n"
            << "CURRENT INDEX.HTML:\n"
            << current_html;

        return strip_markdown_fence(
            generate_text(
                builder_model_,
                instruction.str(),
                0.35
            )
        );
    }

private:
    std::string api_key_;
    std::string builder_model_;
    std::string judge_model_;

    static std::string endpoint(
        const std::string& model
    ) {
        return
            "https://generativelanguage.googleapis.com/"
            "v1beta/models/" +
            model +
            ":generateContent";
    }

    std::string generate_text(
        const std::string& model,
        const std::string& prompt,
        double temperature
    ) const {
        const json request_body = {
            {
                "contents",
                json::array({
                    {
                        {"role", "user"},
                        {
                            "parts",
                            json::array({
                                {
                                    {"text", prompt}
                                }
                            })
                        }
                    }
                })
            },
            {
                "generationConfig",
                {
                    {"temperature", temperature}
                }
            }
        };

        const HttpResponse response = post_json(
            endpoint(model),
            api_key_,
            request_body.dump()
        );

        return extract_gemini_text(response);
    }
};

class StaticServer {
public:
    explicit StaticServer(fs::path root)
        : root_(std::move(root)) {}

    ~StaticServer() {
        stop();
    }

    void start() {
#if defined(__unix__) || defined(__APPLE__)
        if (running_) {
            return;
        }

        server_fd_ = socket(
            AF_INET,
            SOCK_STREAM,
            0
        );

        if (server_fd_ < 0) {
            throw std::runtime_error(
                "Unable to create preview socket"
            );
        }

        int reuse = 1;

        setsockopt(
            server_fd_,
            SOL_SOCKET,
            SO_REUSEADDR,
            &reuse,
            sizeof(reuse)
        );

        sockaddr_in address{};
        address.sin_family = AF_INET;
        address.sin_addr.s_addr =
            htonl(INADDR_LOOPBACK);
        address.sin_port = htons(g_server_port);

        if (
            bind(
                server_fd_,
                reinterpret_cast<sockaddr*>(&address),
                sizeof(address)
            ) < 0
        ) {
            close(server_fd_);
            server_fd_ = -1;

            throw std::runtime_error(
                "Unable to bind preview server to port " +
                std::to_string(g_server_port)
            );
        }

        if (listen(server_fd_, 16) < 0) {
            close(server_fd_);
            server_fd_ = -1;

            throw std::runtime_error(
                "Unable to listen on preview port"
            );
        }

        sockaddr_in assigned_address{};
        socklen_t assigned_length = sizeof(assigned_address);

        if (
            getsockname(
                server_fd_,
                reinterpret_cast<sockaddr*>(&assigned_address),
                &assigned_length
            ) < 0
        ) {
            close(server_fd_);
            server_fd_ = -1;

            throw std::runtime_error(
                "Unable to determine assigned preview port"
            );
        }

        g_server_port = ntohs(assigned_address.sin_port);

        if (g_server_port <= 0) {
            close(server_fd_);
            server_fd_ = -1;

            throw std::runtime_error(
                "Operating system did not assign a preview port"
            );
        }

        running_ = true;

        worker_ = std::thread(
            [this]() {
                serve_loop();
            }
        );

        std::this_thread::sleep_for(
            std::chrono::milliseconds(250)
        );
#else
        throw std::runtime_error(
            "The current preview server requires Unix or WSL"
        );
#endif
    }

    void stop() {
#if defined(__unix__) || defined(__APPLE__)
        if (!running_) {
            return;
        }

        running_ = false;

        if (server_fd_ >= 0) {
            shutdown(server_fd_, SHUT_RDWR);
            close(server_fd_);
            server_fd_ = -1;
        }

        if (worker_.joinable()) {
            worker_.join();
        }
#endif
    }

private:
    fs::path root_;
    std::atomic<bool> running_{false};
    int server_fd_ = -1;
    std::thread worker_;

#if defined(__unix__) || defined(__APPLE__)
    static std::string content_type(
        const fs::path& path
    ) {
        const std::string extension =
            lower(path.extension().string());

        if (extension == ".html") {
            return "text/html; charset=utf-8";
        }

        if (extension == ".css") {
            return "text/css; charset=utf-8";
        }

        if (extension == ".js") {
            return "application/javascript; charset=utf-8";
        }

        if (extension == ".json") {
            return "application/json";
        }

        if (extension == ".png") {
            return "image/png";
        }

        if (
            extension == ".jpg" ||
            extension == ".jpeg"
        ) {
            return "image/jpeg";
        }

        if (extension == ".svg") {
            return "image/svg+xml";
        }

        return "application/octet-stream";
    }

    void serve_loop() {
        while (running_) {
            sockaddr_in client_address{};
            socklen_t client_length =
                sizeof(client_address);

            const int client = accept(
                server_fd_,
                reinterpret_cast<sockaddr*>(
                    &client_address
                ),
                &client_length
            );

            if (client < 0) {
                if (!running_) {
                    break;
                }

                continue;
            }

            handle_client(client);
            close(client);
        }
    }

    void handle_client(int client) {
        std::string request;
        char buffer[8192];

        const ssize_t bytes =
            recv(client, buffer, sizeof(buffer), 0);

        if (bytes <= 0) {
            return;
        }

        request.assign(
            buffer,
            static_cast<std::size_t>(bytes)
        );

        std::istringstream parser(request);

        std::string method;
        std::string target;
        std::string protocol;

        parser >> method >> target >> protocol;

        if (method != "GET") {
            send_response(
                client,
                405,
                "text/plain",
                "Method Not Allowed"
            );

            return;
        }

        const auto query = target.find('?');

        if (query != std::string::npos) {
            target.erase(query);
        }

        if (
            target.find("..") != std::string::npos
        ) {
            send_response(
                client,
                403,
                "text/plain",
                "Forbidden"
            );

            return;
        }

        while (
            !target.empty() &&
            target.front() == '/'
        ) {
            target.erase(target.begin());
        }

        fs::path requested =
            target.empty()
                ? root_ / "index.html"
                : root_ / target;

        std::error_code error;

        if (fs::is_directory(requested, error)) {
            requested /= "index.html";
        }

        if (!fs::exists(requested, error)) {
            requested = root_ / "index.html";
        }

        try {
            send_response(
                client,
                200,
                content_type(requested),
                read_file(requested)
            );
        } catch (...) {
            send_response(
                client,
                500,
                "text/plain",
                "Internal Server Error"
            );
        }
    }

    static void send_response(
        int client,
        int status,
        const std::string& type,
        const std::string& body
    ) {
        std::ostringstream response;

        response
            << "HTTP/1.1 " << status
            << (
                status == 200
                    ? " OK\r\n"
                    : " Error\r\n"
            )
            << "Content-Type: " << type << "\r\n"
            << "Content-Length: "
            << body.size() << "\r\n"
            << "Connection: close\r\n"
            << "Cache-Control: no-store\r\n"
            << "\r\n"
            << body;

        const std::string data = response.str();

        std::size_t sent = 0;

        while (sent < data.size()) {
            const ssize_t result = send(
                client,
                data.data() + sent,
                data.size() - sent,
                0
            );

            if (result <= 0) {
                break;
            }

            sent +=
                static_cast<std::size_t>(result);
        }
    }
#endif
};

std::vector<std::string> discover_routes(
    const std::string& html
) {
    std::set<std::string> routes = {"/"};

    const std::regex link_pattern(
        R"REGEX(href\s*=\s*["']([^"'#]+)["'])REGEX",
        std::regex::icase
    );

    for (
        std::sregex_iterator iterator(
            html.begin(),
            html.end(),
            link_pattern
        );
        iterator != std::sregex_iterator();
        ++iterator
    ) {
        std::string route = trim(
            (*iterator)[1].str()
        );

        if (
            route.empty() ||
            route.rfind("http://", 0) == 0 ||
            route.rfind("https://", 0) == 0 ||
            route.rfind("mailto:", 0) == 0 ||
            route.rfind("tel:", 0) == 0 ||
            route.rfind("javascript:", 0) == 0
        ) {
            continue;
        }

        const auto query = route.find('?');

        if (query != std::string::npos) {
            route.erase(query);
        }

        if (route.front() != '/') {
            route.insert(route.begin(), '/');
        }

        if (
            route.find('.') == std::string::npos
        ) {
            routes.insert(route);
        }
    }

    return {
        routes.begin(),
        routes.end()
    };
}

std::string safe_route_name(
    const std::string& route
) {
    if (route == "/") {
        return "home";
    }

    std::string name;

    for (char character : route) {
        if (std::isalnum(
            static_cast<unsigned char>(character)
        )) {
            name += character;
        } else {
            name += '_';
        }
    }

    while (
        !name.empty() &&
        name.front() == '_'
    ) {
        name.erase(name.begin());
    }

    return name.empty()
        ? "page"
        : name;
}

class VisualCapture {
public:
    explicit VisualCapture(std::string chromium)
        : chromium_(std::move(chromium)) {}

    std::vector<Capture> capture_all(
        const std::vector<std::string>& routes,
        const fs::path& output_directory
    ) const {
        fs::create_directories(output_directory);

        std::vector<Capture> captures;

        for (const std::string& route : routes) {
            capture_viewport(
                route,
                "desktop",
                1440,
                1000,
                output_directory,
                captures
            );

            capture_viewport(
                route,
                "mobile",
                390,
                844,
                output_directory,
                captures
            );

            capture_long_page_portions(
                route,
                output_directory,
                captures
            );
        }

        return captures;
    }

private:
    std::string chromium_;

    void capture_viewport(
        const std::string& route,
        const std::string& viewport,
        int width,
        int height,
        const fs::path& output_directory,
        std::vector<Capture>& captures
    ) const {
        const std::string route_name =
            safe_route_name(route);

        const fs::path screenshot =
            output_directory /
            (
                route_name + "-" +
                viewport + ".png"
            );

        const std::string url =
            "http://127.0.0.1:" +
            std::to_string(g_server_port) +
            route;

        const std::string command =
            shell_quote(chromium_) +
            " --headless=new"
            " --disable-gpu"
            " --disable-dev-shm-usage"
            " --no-sandbox"
            " --hide-scrollbars"
            " --run-all-compositor-stages-before-draw"
            " --virtual-time-budget=5000"
            " --window-size=" +
            std::to_string(width) +
            "," +
            std::to_string(height) +
            " --screenshot=" +
            shell_quote(screenshot.string()) +
            " " +
            shell_quote(url) +
            " >/dev/null 2>&1";

        const int result = std::system(
            command.c_str()
        );

        if (
            result == 0 &&
            fs::exists(screenshot)
        ) {
            captures.push_back({
                route,
                viewport,
                "viewport",
                screenshot
            });
        }
    }

    void capture_long_page_portions(
        const std::string& route,
        const fs::path& output_directory,
        std::vector<Capture>& captures
    ) const {
        if (!command_exists("pdftoppm")) {
            return;
        }

        const std::string route_name =
            safe_route_name(route);

        const fs::path pdf =
            output_directory /
            (route_name + "-full.pdf");

        const std::string url =
            "http://127.0.0.1:" +
            std::to_string(g_server_port) +
            route;

        const std::string print_command =
            shell_quote(chromium_) +
            " --headless=new"
            " --disable-gpu"
            " --disable-dev-shm-usage"
            " --no-sandbox"
            " --run-all-compositor-stages-before-draw"
            " --virtual-time-budget=5000"
            " --no-pdf-header-footer"
            " --print-to-pdf=" +
            shell_quote(pdf.string()) +
            " " +
            shell_quote(url) +
            " >/dev/null 2>&1";

        if (
            std::system(print_command.c_str()) != 0 ||
            !fs::exists(pdf)
        ) {
            return;
        }

        const fs::path prefix =
            output_directory /
            (route_name + "-portion");

        const std::string convert_command =
            "pdftoppm -png -r 120 " +
            shell_quote(pdf.string()) +
            " " +
            shell_quote(prefix.string()) +
            " >/dev/null 2>&1";

        if (
            std::system(convert_command.c_str()) != 0
        ) {
            return;
        }

        std::vector<fs::path> portions;

        for (
            const auto& entry :
            fs::directory_iterator(output_directory)
        ) {
            if (!entry.is_regular_file()) {
                continue;
            }

            const std::string filename =
                entry.path().filename().string();

            if (
                filename.rfind(
                    route_name + "-portion-",
                    0
                ) == 0 &&
                lower(
                    entry.path().extension().string()
                ) == ".png"
            ) {
                portions.push_back(entry.path());
            }
        }

        std::sort(
            portions.begin(),
            portions.end()
        );

        for (
            std::size_t index = 0;
            index < portions.size();
            ++index
        ) {
            captures.push_back({
                route,
                "desktop",
                "portion-" +
                    std::to_string(index + 1),
                portions[index]
            });
        }
    }
};

void open_browser(const std::string& url) {
    std::string command;

    if (command_exists("wslview")) {
        command =
            "wslview " +
            shell_quote(url) +
            " >/dev/null 2>&1 &";
    } else if (command_exists("powershell.exe")) {
        command =
            "powershell.exe -NoProfile -Command "
            "\"Start-Process '" +
            url +
            "'\" >/dev/null 2>&1";
    } else if (command_exists("xdg-open")) {
        command =
            "xdg-open " +
            shell_quote(url) +
            " >/dev/null 2>&1 &";
    } else {
        std::cout
            << "Open manually: "
            << url << '\n';

        return;
    }

    std::system(command.c_str());
}

std::string join_arguments(
    int argc,
    char* argv[],
    int start
) {
    std::string prompt;

    for (int index = start; index < argc; ++index) {
        if (!prompt.empty()) {
            prompt += ' ';
        }

        prompt += argv[index];
    }

    return prompt;
}

void print_report(
    int iteration,
    const Evaluation& evaluation
) {
    std::cout
        << "\nIteration " << iteration
        << " evaluation\n"
        << "────────────────────────\n"
        << "Score              : "
        << evaluation.score << "/100\n"
        << "Critical issues    : "
        << evaluation.critical_issues << '\n'
        << "Unmet requirements : "
        << evaluation.unmet_requirements << '\n'
        << "Accepted           : "
        << (
            evaluation.accepted
                ? "yes"
                : "no"
        )
        << '\n'
        << "Summary            : "
        << evaluation.summary
        << "\n";
}

void print_usage() {
    std::cout
        << "NIFDU C++ Visual Product Supervisor 2.0\n\n"
        << "Usage:\n"
        << "  nifdu build \"customer request\"\n"
        << "  nifdu \"customer request\"\n\n"
        << "Example:\n"
        << "  nifdu build \"Create a premium cats website "
        << "with gallery, adoption cards and contact form\"\n\n"
        << "Environment:\n"
        << "  GEMINI_API_KEY       required\n"
        << "  NIFDU_BUILDER_MODEL  default: gemini-2.5-flash\n"
        << "  NIFDU_JUDGE_MODEL    default: gemini-2.5-flash\n"
        << "  NIFDU_CHROMIUM       optional browser command\n\n"
        << "Quality loop:\n"
        << "  Maximum iterations : "
        << MAX_ITERATIONS << '\n'
        << "  Acceptance score   : "
        << ACCEPTANCE_SCORE << "/100\n";
}

} // namespace

int main(int argc, char* argv[]) {
    try {
        if (argc < 2) {
            print_usage();
            return EXIT_SUCCESS;
        }

        const std::string api_key =
            env(
                "GEMINI_API_KEY",
                env("NIFDU_API_KEY")
            );

        if (api_key.empty()) {
            std::cerr
                << "No Gemini API key found.\n"
                << "Run:\n"
                << "  export GEMINI_API_KEY='your-key'\n";

            return EXIT_FAILURE;
        }

        int prompt_start = 1;

        if (
            std::string(argv[1]) == "build" ||
            std::string(argv[1]) == "create"
        ) {
            prompt_start = 2;
        }

        if (argc <= prompt_start) {
            print_usage();
            return EXIT_FAILURE;
        }

        const std::string requirement =
            join_arguments(
                argc,
                argv,
                prompt_start
            );

        const std::string builder_model = env(
            "NIFDU_BUILDER_MODEL",
            "gemini-2.5-flash"
        );

        const std::string judge_model = env(
            "NIFDU_JUDGE_MODEL",
            builder_model
        );

        const fs::path workspace =
            fs::path(env("HOME")) /
            "nifdu-workspaces" /
            ("product-" + timestamp());

        const fs::path product_directory =
            workspace / "product";

        fs::create_directories(product_directory);

        write_file(
            workspace / "customer-requirement.txt",
            requirement + "\n"
        );

        const std::string chromium =
            find_chromium();

        GeminiClient gemini(
            api_key,
            builder_model,
            judge_model
        );

        VisualCapture visual_capture(chromium);

        std::cout
            << "NIFDU autonomous product loop\n"
            << "Workspace     : "
            << workspace << '\n'
            << "Builder model : "
            << builder_model << '\n'
            << "Judge model   : "
            << judge_model << '\n'
            << "Max loops     : "
            << MAX_ITERATIONS << "\n\n"
            << "Generating initial product...\n";

        std::string html =
            gemini.build_initial(requirement);

        if (
            lower(html).find("<!doctype html") ==
                std::string::npos &&
            lower(html).find("<html") ==
                std::string::npos
        ) {
            throw std::runtime_error(
                "Builder did not return a valid HTML document"
            );
        }

        write_file(
            product_directory / "index.html",
            html
        );

        StaticServer server(product_directory);
        server.start();

        Evaluation latest;
        int completed_iterations = 0;

        for (
            int iteration = 1;
            iteration <= MAX_ITERATIONS;
            ++iteration
        ) {
            completed_iterations = iteration;

            const fs::path iteration_directory =
                workspace /
                (
                    "iteration-" +
                    std::to_string(iteration)
                );

            const fs::path capture_directory =
                iteration_directory /
                "captures";

            fs::create_directories(
                capture_directory
            );

            html = read_file(
                product_directory / "index.html"
            );

            write_file(
                iteration_directory /
                    "input-index.html",
                html
            );

            const std::vector<std::string> routes =
                discover_routes(html);

            json route_report = json::array();

            for (const std::string& route : routes) {
                route_report.push_back(route);
            }

            write_file(
                iteration_directory / "routes.json",
                route_report.dump(2)
            );

            std::cout
                << "\nIteration "
                << iteration
                << "/"
                << MAX_ITERATIONS
                << "\nCapturing "
                << routes.size()
                << " route(s)...\n";

            const std::vector<Capture> captures =
                visual_capture.capture_all(
                    routes,
                    capture_directory
                );

            json capture_report = json::array();

            for (const Capture& capture : captures) {
                capture_report.push_back({
                    {"route", capture.route},
                    {"viewport", capture.viewport},
                    {"kind", capture.kind},
                    {"path", capture.path.string()}
                });
            }

            write_file(
                iteration_directory /
                    "captures.json",
                capture_report.dump(2)
            );

            std::cout
                << "Captured "
                << captures.size()
                << " visual artifact(s).\n"
                << "Sending evidence to independent judge...\n";

            latest = gemini.judge(
                requirement,
                html,
                captures,
                iteration
            );

            write_file(
                iteration_directory /
                    "judge-report.json",
                latest.raw.dump(2)
            );

            print_report(
                iteration,
                latest
            );

            if (latest.accepted) {
                write_file(
                    iteration_directory /
                        "accepted.txt",
                    "Accepted\n"
                );

                break;
            }

            if (iteration == MAX_ITERATIONS) {
                break;
            }

            std::cout
                << "Applying judge-required repairs...\n";

            const std::string repaired =
                gemini.repair(
                    requirement,
                    html,
                    latest,
                    iteration
                );

            if (
                lower(repaired).find("<html") ==
                std::string::npos
            ) {
                throw std::runtime_error(
                    "Repair model returned invalid HTML"
                );
            }

            write_file(
                iteration_directory /
                    "repaired-index.html",
                repaired
            );

            write_file(
                product_directory /
                    "index.html",
                repaired
            );
        }

        const json final_report = {
            {"accepted", latest.accepted},
            {"score", latest.score},
            {
                "critical_issues",
                latest.critical_issues
            },
            {
                "unmet_requirements",
                latest.unmet_requirements
            },
            {
                "iterations",
                completed_iterations
            },
            {"summary", latest.summary},
            {
                "final_file",
                (
                    product_directory /
                    "index.html"
                ).string()
            },
            {
                "preview",
                "http://127.0.0.1:" +
                std::to_string(g_server_port)
            }
        };

        write_file(
            workspace / "final-report.json",
            final_report.dump(2)
        );

        std::cout
            << "\nFinal product\n"
            << "────────────────────────\n"
            << "Status     : "
            << (
                latest.accepted
                    ? "ACCEPTED"
                    : "MAXIMUM ITERATIONS EXPIRED"
            )
            << '\n'
            << "Score      : "
            << latest.score << "/100\n"
            << "Iterations : "
            << completed_iterations << '\n'
            << "Product    : "
            << product_directory /
                   "index.html"
            << '\n'
            << "Report     : "
            << workspace /
                   "final-report.json"
            << '\n'
            << "Preview    : http://127.0.0.1:"
            << g_server_port
            << "\n\nOpening final product...\n";

        open_browser(
            "http://127.0.0.1:" +
            std::to_string(g_server_port)
        );

        std::cout
            << "Press Enter to stop the preview server.\n";

        std::string line;
        std::getline(std::cin, line);

        server.stop();

        return latest.accepted
            ? EXIT_SUCCESS
            : 2;
    } catch (const std::exception& error) {
        std::cerr
            << "\nNIFDU fatal error: "
            << error.what()
            << '\n';

        return EXIT_FAILURE;
    }
}
