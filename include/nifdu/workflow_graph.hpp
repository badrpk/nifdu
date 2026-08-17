#ifndef NIFDU_WORKFLOW_GRAPH_HPP
#define NIFDU_WORKFLOW_GRAPH_HPP

#include <nlohmann/json.hpp>
#include <string>
#include <vector>
#include <map>
#include <functional>
#include <memory>

namespace nifdu {

using json = nlohmann::json;

using GraphState = json;
using NodeHandler = std::function<GraphState(const GraphState& current_state)>;
using EdgeCondition = std::function<std::string(const GraphState& current_state)>;

struct GraphCheckpoint {
    std::string checkpoint_id;
    std::string thread_id;
    int step_index = 0;
    std::string current_node;
    GraphState state;
    std::string timestamp;
};

class GraphWorkflow {
public:
    explicit GraphWorkflow(std::string name);

    void add_node(const std::string& name, NodeHandler handler, bool interrupt_before = false);
    void add_edge(const std::string& from_node, const std::string& to_node);
    void add_conditional_edges(const std::string& from_node, EdgeCondition condition, const std::map<std::string, std::string>& path_map);
    
    void set_entry_point(const std::string& node_name);

    // Execution & HITL
    json run(const std::string& thread_id, const GraphState& initial_state);
    json approve_and_continue(const std::string& thread_id, const GraphState& updated_state = {});

    // Time-Travel Checkpoint & Rewind
    GraphCheckpoint get_checkpoint(const std::string& checkpoint_id);
    json rewind_to_checkpoint(const std::string& checkpoint_id);

private:
    std::string name_;
    std::string entry_point_;
    std::map<std::string, NodeHandler> nodes_;
    std::map<std::string, bool> interrupt_nodes_;
    std::map<std::string, std::string> direct_edges_;
    std::map<std::string, std::pair<EdgeCondition, std::map<std::string, std::string>>> conditional_edges_;

    std::map<std::string, std::vector<GraphCheckpoint>> thread_checkpoints_;
    std::map<std::string, GraphCheckpoint> active_interrupts_;
};

} // namespace nifdu

#endif // NIFDU_WORKFLOW_GRAPH_HPP
