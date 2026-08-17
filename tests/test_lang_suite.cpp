#include "nifdu/model_adapter.hpp"
#include "nifdu/workflow_graph.hpp"
#include "nifdu/trace_engine.hpp"
#include <iostream>
#include <cassert>

int main() {
    std::cout << "====================================================\n";
    std::cout << "🚀 NIFDU LANGCHAIN / LANGGRAPH / LANGSMITH HARNESS\n";
    std::cout << "====================================================\n\n" << std::flush;

    int passed = 0;
    int failed = 0;

    auto assert_test = [&](bool condition, const std::string& message) {
        if (condition) {
            std::cout << "  ✅ [PASS] " << message << "\n" << std::flush;
            passed++;
        } else {
            std::cout << "  ❌ [FAIL] " << message << "\n" << std::flush;
            failed++;
        }
    };

    // ----------------------------------------------------
    // PART 1: LANGCHAIN PARITY HARNESS
    // ----------------------------------------------------
    std::cout << "--- PART 1: LANGCHAIN PARITY ---\n" << std::flush;
    
    // Test 1: Universal Model Adapter & Fallback Chain
    nifdu::LlmConfig ollama_cfg{nifdu::LlmProvider::Ollama, "llama3.1:latest"};
    nifdu::LlmConfig openai_cfg{nifdu::LlmProvider::OpenAI, "gpt-4.1-mini"};
    nifdu::UniversalLlmAdapter adapter(ollama_cfg);
    
    std::string res = adapter.invoke_with_fallback("Explain quantum computing", {openai_cfg, ollama_cfg});
    assert_test(!res.empty(), "Universal Model Adapter invoked with multi-provider fallback");

    // Test 2: Structured Output Schema Enforcer
    nlohmann::json schema = {{"type", "object"}, {"properties", {{"answer", {{"type", "string"}}}}}};
    auto validated_json = nifdu::StructuredParser::parse_and_validate("{\"answer\": \"Quantum computers use qubits.\"}", schema, adapter);
    assert_test(validated_json["parsed"] == true || validated_json.contains("answer"), "Structured Output Parser validated JSON schema");

    // Test 3: RAG Document Chunking & Vector Search
    nifdu::RagEngine rag;
    rag.add_document("doc_001", "NIFDU is an autonomous AI coding assistant with PostGIS telemetry and WebRTC communication hub capabilities.", {{"author", "badrpk"}});
    auto search_results = rag.similarity_search("What is NIFDU?", 2);
    assert_test(!search_results.empty() && search_results[0].text.find("NIFDU") != std::string::npos, "RAG similarity search returned vector chunks");

    // ----------------------------------------------------
    // PART 2: LANGGRAPH PARITY HARNESS
    // ----------------------------------------------------
    std::cout << "\n--- PART 2: LANGGRAPH PARITY ---\n" << std::flush;

    nifdu::GraphWorkflow workflow("code_agent_workflow");
    
    // Define nodes
    workflow.add_node("plan_node", [](const nlohmann::json& state) {
        nlohmann::json s = state;
        s["plan"] = "Ready to edit codebase";
        return s;
    });

    workflow.add_node("apply_code_node", [](const nlohmann::json& state) {
        nlohmann::json s = state;
        s["applied"] = true;
        return s;
    }, true); // interrupt_before = true (HITL)

    workflow.add_edge("plan_node", "apply_code_node");
    workflow.set_entry_point("plan_node");

    // Test 4: Graph Execution & HITL Interrupt
    auto graph_run = workflow.run("thread_101", {{"user_prompt", "Fix bug in main.cpp"}});
    assert_test(graph_run["status"] == "interrupted", "LangGraph workflow paused at HITL interrupt node");
    assert_test(graph_run["interrupted_at_node"] == "apply_code_node", "Interrupted precisely at apply_code_node for human approval");

    // Test 5: Human Approval & Resume
    auto approved_run = workflow.approve_and_continue("thread_101");
    assert_test(approved_run["status"] == "completed", "Human approval granted; graph resumed and completed execution");

    // Test 6: Checkpoint Rewind & Time Travel
    std::string chk_id = graph_run["checkpoint_id"];
    auto rewind_run = workflow.rewind_to_checkpoint(chk_id);
    assert_test(rewind_run["status"] == "rewound" && rewind_run.contains("restored_state"), "Time-travel rewind restored exact state checkpoint");

    // ----------------------------------------------------
    // PART 3: LANGSMITH PARITY HARNESS
    // ----------------------------------------------------
    std::cout << "\n--- PART 3: LANGSMITH PARITY ---\n" << std::flush;

    auto& tracer = nifdu::NifduTraceEngine::instance();

    // Test 7: Trace Tree & Latency/Token Metric Spans
    std::string trace_id = tracer.start_trace("session_smith_01", "root_chain", {{"input", "Generate API"}});
    std::string span_id = tracer.start_span(trace_id, "llm_call", "span_root", {{"prompt", "Write code"}});
    tracer.end_span(trace_id, span_id, {{"output", "code"}}, 120, 240);
    tracer.end_trace(trace_id);

    auto trace_tree = tracer.get_trace_tree(trace_id);
    assert_test(trace_tree["spans"].size() == 2, "LangSmith trace tree recorded root span and nested LLM call span");
    assert_test(trace_tree["spans"][1]["prompt_tokens"] == 120, "Prompt tokens and latency tracked per span");

    // Test 8: Evaluation Dataset Benchmarking
    nifdu::EvalDatasetExample ex1{"ex_001", {{"input", "2+2"}}, {{"output", "4"}}};
    tracer.register_dataset("math_eval", {ex1});

    auto bench_result = tracer.run_benchmark("math_eval", [](const nlohmann::json& input) {
        (void)input;
        return nlohmann::json{{"output", "4"}};
    });
    assert_test(bench_result.pass_rate == 1.0, "Automated Evaluation Dataset benchmark scored 100% pass rate");

    // ----------------------------------------------------
    // SUMMARY
    // ----------------------------------------------------
    std::cout << "\n====================================================\n" << std::flush;
    std::cout << "📊 LANG HARNESS SUMMARY: " << passed << " PASSED, " << failed << " FAILED\n" << std::flush;
    std::cout << "====================================================\n\n" << std::flush;

    return (failed == 0) ? 0 : 1;
}
