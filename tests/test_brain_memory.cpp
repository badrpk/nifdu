#include "nifdu/brain_memory.hpp"

#include <cassert>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <vector>

#include <nlohmann/json.hpp>

namespace fs =
    std::filesystem;

using json =
    nlohmann::json;

static void write_embedding(
    const fs::path& root,
    const std::string& rid,
    const std::vector<double>& embedding,
    const std::string& project
)
{
    fs::create_directories(
        root /
        "embeddings"
    );

    std::ofstream out(
        root /
        "embeddings" /
        (
            "embedding_" +
            rid +
            ".json"
        )
    );

    out << json{
        {"rid", rid},
        {"tenant", "local"},
        {"user", "local"},
        {"project", project},
        {"surface", "test"},
        {"event_path", ""},
        {"embedding", embedding}
    }.dump();
}

int main()
{
    using namespace
        nifdu::brain;

    const fs::path root =
        fs::temp_directory_path()
        / "nifdu-brain-memory-test";

    std::error_code ec;

    fs::remove_all(
        root,
        ec
    );

    DiskMemory memory(root);

    assert(
        memory.status().ok
    );

    write_embedding(
        root,
        "exact",
        {
            1.0,
            0.0,
            0.0
        },
        "alpha"
    );

    write_embedding(
        root,
        "orthogonal",
        {
            0.0,
            1.0,
            0.0
        },
        "alpha"
    );

    write_embedding(
        root,
        "other-project",
        {
            1.0,
            0.0,
            0.0
        },
        "beta"
    );

    assert(
        memory.reload_index()
        == 3
    );

    Scope alpha;

    alpha.tenant =
        "local";

    alpha.user =
        "local";

    alpha.project =
        "alpha";

    const auto first =
        memory.search(
            {
                1.0,
                0.0,
                0.0
            },
            10,
            alpha
        );

    assert(
        first.size()
        == 2
    );

    assert(
        first[0]
            .record
            .rid
        == "exact"
    );

    assert(
        std::fabs(
            first[0].score -
            1.0
        ) < 1e-9
    );

    write_embedding(
        root,
        "new-record",
        {
            1.0,
            0.0,
            0.0
        },
        "alpha"
    );

    /*
     * Index remains stable until
     * explicit reload.
     */
    const auto before_reload =
        memory.search(
            {
                1.0,
                0.0,
                0.0
            },
            10,
            alpha
        );

    assert(
        before_reload.size()
        == 2
    );

    assert(
        memory.reload_index()
        == 4
    );

    const auto after_reload =
        memory.search(
            {
                1.0,
                0.0,
                0.0
            },
            10,
            alpha
        );

    assert(
        after_reload.size()
        == 3
    );

    const std::string rid =
        memory.queue_query(
            "Iran USA issue",
            alpha
        );

    assert(!rid.empty());

    const auto status =
        memory.status();

    assert(
        status.index_loaded
    );

    assert(
        status.indexed_records
        == 4
    );

    assert(
        status.queued
        == 1
    );

    assert(
        status.events
        == 1
    );

    fs::remove_all(
        root,
        ec
    );

    std::cout
        << "PASS: native brain "
        << "hot-index memory kernel\n";

    return 0;
}
