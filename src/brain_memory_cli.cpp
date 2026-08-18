#include "nifdu/brain_memory.hpp"

#include <nlohmann/json.hpp>

#include <iostream>
#include <string>

using json = nlohmann::json;

int main(
    int argc,
    char** argv
)
{
    using nifdu::brain::DiskMemory;
    using nifdu::brain::Scope;

    if (argc < 2) {
        std::cerr
            << "usage: nifdu-memory "
            << "status|reload|queue-query\n";

        return 2;
    }

    DiskMemory memory;

    const std::string command =
        argv[1];

    if (command == "status") {
        const auto s =
            memory.status();

        std::cout << json{
            {
                "ok",
                s.ok
            },
            {
                "root",
                s.root.string()
            },
            {
                "embeddings",
                s.embeddings
            },
            {
                "index_loaded",
                s.index_loaded
            },
            {
                "indexed_records",
                s.indexed_records
            },
            {
                "queued",
                s.queued
            },
            {
                "events",
                s.events
            }
        }.dump(2)
          << '\n';

        return s.ok ? 0 : 1;
    }

    if (command == "reload") {
        const std::size_t n =
            memory.reload_index();

        std::cout << json{
            {"ok", true},
            {
                "indexed_records",
                n
            }
        }.dump(2)
          << '\n';

        return 0;
    }

    if (
        command ==
        "queue-query"
    ) {
        if (argc < 3) {
            std::cerr
                << "queue-query "
                << "requires text\n";

            return 2;
        }

        Scope scope;

        scope.tenant =
            "local";

        scope.user =
            "local";

        scope.project =
            "global";

        const std::string rid =
            memory.queue_query(
                argv[2],
                scope
            );

        std::cout << json{
            {"ok", true},
            {"rid", rid}
        }.dump(2)
          << '\n';

        return 0;
    }

    std::cerr
        << "unknown command\n";

    return 2;
}
