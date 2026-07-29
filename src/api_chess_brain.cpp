#include <boost/beast/http.hpp>
#include <nlohmann/json.hpp>
#include <string>
#include <vector>

#include "truth_engine.hpp"   // your existing engine header – adjust if needed

namespace beast = boost::beast;
namespace http  = beast::http;
using json      = nlohmann::json;

// ----------------------
// Helpers
// ----------------------

static http::response<http::string_body>
make_json_response(const json& j, http::status status = http::status::ok)
{
    http::response<http::string_body> res{status, 11};
    res.set(http::field::server, "NIFDU/chess-brain");
    res.set(http::field::content_type, "application/json; charset=utf-8");
    res.body() = j.dump();
    res.prepare_payload();
    return res;
}

static http::response<http::string_body>
make_error(const std::string& msg, http::status st = http::status::bad_request)
{
    json j;
    j["error"] = msg;
    return make_json_response(j, st);
}

// ----------------------
// /api/truth  (deterministic engine)
// ----------------------

http::message_generator handle_api_truth(http::request<http::string_body>&& req)
{
    try {
        if (req.method() != http::verb::post)
            return make_error("Use POST", http::status::method_not_allowed);

        auto j = json::parse(req.body(), nullptr, true, true);

        std::string fen       = j.value("fen", "");
        std::vector<std::string> moves =
            j.value("moves", std::vector<std::string>{});
        int max_depth = j.value("max_depth", 4);

        if (fen.empty())
            return make_error("Missing 'fen' field");

        // Call your existing engine
        TruthEngine engine;  // assume default-constructible
        auto result = engine.analyze_position(fen, moves, max_depth);
        // You define 'analyze_position' signature – here’s one suggestion:
        // struct TruthResult { std::string best_move; int score_cp; int mate_in;
        //                       std::vector<std::string> pv; std::uint64_t nodes; int depth; };

        json out;
        out["engine"]              = "nifdu-truth";
        out["best_move"]           = result.best_move;
        out["score_cp"]            = result.score_cp;
        out["mate_in"]             = result.mate_in;
        out["principal_variation"] = result.pv;
        out["nodes"]               = result.nodes;
        out["depth"]               = result.depth;

        return make_json_response(out);
    } catch (const std::exception& e) {
        return make_error(std::string("truth error: ") + e.what(),
                          http::status::internal_server_error);
    }
}

// ----------------------
// Tiny in-memory RL stub
// (you can later back this with a file / DB / pgvector)
// ----------------------

struct RlState {
    // Very simple table: key = FEN + " " + action
    std::unordered_map<std::string, double> q;
    double alpha = 0.3; // learning rate
    double gamma = 0.95; // discount
};

static RlState g_rl_state;

static double rl_key_get(const std::string& key) {
    auto it = g_rl_state.q.find(key);
    if (it == g_rl_state.q.end()) return 0.0;
    return it->second;
}

static void rl_key_set(const std::string& key, double v) {
    g_rl_state.q[key] = v;
}

http::message_generator handle_api_rl(http::request<http::string_body>&& req)
{
    try {
        if (req.method() != http::verb::post)
            return make_error("Use POST", http::status::method_not_allowed);

        auto j = json::parse(req.body(), nullptr, true, true);

        std::string episode_id = j.value("episode_id", "");
        std::string fen        = j.value("fen", "");
        std::string action     = j.value("action", "");
        double reward          = j.value("reward", 0.0);
        bool done              = j.value("done", false);

        if (fen.empty() || action.empty())
            return make_error("Missing 'fen' or 'action'");

        const std::string key = fen + " " + action;
        double old_q          = rl_key_get(key);

        // For now, next-state maxQ is 0 (you can extend with next_fen etc.)
        double max_next_q = 0.0;

        double target = reward + (done ? 0.0 : g_rl_state.gamma * max_next_q);
        double new_q  = old_q + g_rl_state.alpha * (target - old_q);

        rl_key_set(key, new_q);

        // For now ask TruthEngine again for suggested move (policy step)
        TruthEngine engine;
        auto tr = engine.analyze_position(fen, {}, 3);

        json out;
        out["engine"]             = "nifdu-rl";
        out["episode_id"]         = episode_id;
        out["action"]             = action;
        out["old_q_value"]        = old_q;
        out["new_q_value"]        = new_q;
        out["suggested_next_move"] = tr.best_move;

        return make_json_response(out);
    } catch (const std::exception& e) {
        return make_error(std::string("rl error: ") + e.what(),
                          http::status::internal_server_error);
    }
}

// ----------------------
// /api/rag  (chess knowledge / openings DB)
// Stub: just echoes; later you plug in pgvector / local docs
// ----------------------

http::message_generator handle_api_rag(http::request<http::string_body>&& req)
{
    try {
        if (req.method() != http::verb::post)
            return make_error("Use POST", http::status::method_not_allowed);

        auto j = json::parse(req.body(), nullptr, true, true);

        std::string fen      = j.value("fen", "");
        std::string question = j.value("question", "");

        json out;
        out["engine"]  = "nifdu-rag";
        out["fen"]     = fen;
        out["question"] = question;

        // TODO: replace this stub with real RAG:
        out["answer"]  = "RAG placeholder: plug in NIFDU’s chess DB + pgvector here.";
        out["sources"] = json::array();

        return make_json_response(out);
    } catch (const std::exception& e) {
        return make_error(std::string("rag error: ") + e.what(),
                          http::status::internal_server_error);
    }
}
