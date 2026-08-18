#pragma once

#include <cstddef>
#include <filesystem>
#include <shared_mutex>
#include <string>
#include <vector>

namespace nifdu::brain {

struct Scope {
    std::string tenant;
    std::string user;
    std::string project;
};

struct MemoryRecord {
    std::string rid;
    std::string tenant;
    std::string user;
    std::string project;
    std::string surface;
    std::string event_path;
    std::string timestamp;
    std::vector<double> embedding;
};

struct SearchResult {
    double score = 0.0;
    MemoryRecord record;
};

struct Status {
    bool ok = false;
    bool index_loaded = false;

    std::filesystem::path root;

    std::size_t embeddings = 0;
    std::size_t indexed_records = 0;
    std::size_t queued = 0;
    std::size_t events = 0;
};

class DiskMemory {
public:
    explicit DiskMemory(std::filesystem::path root = {});

    const std::filesystem::path& root() const noexcept;

    Status status() const;

    std::size_t reload_index() const;

    std::vector<SearchResult> search(
        const std::vector<double>& query_embedding,
        std::size_t top_k = 10,
        const Scope& scope = {}
    ) const;

    std::string queue_query(
        const std::string& query,
        const Scope& scope = {}
    );

private:
    void ensure_index_loaded() const;

    std::filesystem::path root_;

    mutable std::shared_mutex index_mutex_;
    mutable bool index_loaded_ = false;
    mutable std::vector<MemoryRecord> index_;
};

double cosine_similarity(
    const std::vector<double>& lhs,
    const std::vector<double>& rhs
);

std::filesystem::path default_runtime_root();

} // namespace nifdu::brain
