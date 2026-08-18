#include "nifdu/brain_memory.hpp"

#include <nlohmann/json.hpp>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdlib>
#include <fstream>
#include <iterator>
#include <mutex>
#include <optional>
#include <stdexcept>
#include <system_error>
#include <utility>

namespace fs = std::filesystem;
using json = nlohmann::json;

namespace nifdu::brain {
namespace {

std::string read_text(const fs::path& path)
{
    std::ifstream in(path, std::ios::binary);

    if (!in) {
        return {};
    }

    return std::string(
        std::istreambuf_iterator<char>(in),
        std::istreambuf_iterator<char>()
    );
}

void ensure_runtime_dirs(const fs::path& root)
{
    fs::create_directories(root / "embeddings");
    fs::create_directories(root / "events");
    fs::create_directories(root / "queue");
    fs::create_directories(root / "done");
    fs::create_directories(root / "fail");
}

std::string make_rid()
{
    const auto now =
        std::chrono::system_clock::now();

    const auto us =
        std::chrono::duration_cast<
            std::chrono::microseconds
        >(now.time_since_epoch()).count();

    return "brain_" + std::to_string(us);
}

void atomic_write_json(
    const fs::path& path,
    const json& value
)
{
    fs::create_directories(path.parent_path());

    const fs::path tmp =
        path.string() + ".tmp";

    {
        std::ofstream out(
            tmp,
            std::ios::binary |
            std::ios::trunc
        );

        if (!out) {
            throw std::runtime_error(
                "unable to create temporary memory file"
            );
        }

        out << value.dump();
        out.flush();

        if (!out) {
            throw std::runtime_error(
                "unable to flush temporary memory file"
            );
        }
    }

    std::error_code ec;
    fs::rename(tmp, path, ec);

    if (ec) {
        std::error_code remove_ec;

        fs::remove(path, remove_ec);

        ec.clear();
        fs::rename(tmp, path, ec);

        if (ec) {
            fs::remove(tmp, remove_ec);

            throw std::runtime_error(
                "unable to publish memory file"
            );
        }
    }
}

bool scope_matches(
    const MemoryRecord& record,
    const Scope& scope
)
{
    return
        (
            scope.tenant.empty() ||
            record.tenant == scope.tenant
        ) &&
        (
            scope.user.empty() ||
            record.user == scope.user
        ) &&
        (
            scope.project.empty() ||
            record.project == scope.project
        );
}

std::optional<MemoryRecord>
parse_record(const fs::path& path)
{
    const std::string raw =
        read_text(path);

    if (raw.empty()) {
        return std::nullopt;
    }

    json j;

    try {
        j = json::parse(raw);
    } catch (...) {
        return std::nullopt;
    }

    if (
        !j.is_object() ||
        !j.contains("embedding") ||
        !j["embedding"].is_array()
    ) {
        return std::nullopt;
    }

    MemoryRecord record;

    record.rid =
        j.value("rid", "");

    record.tenant =
        j.value("tenant", "");

    record.user =
        j.value("user", "");

    record.project =
        j.value("project", "");

    record.surface =
        j.value("surface", "");

    record.event_path =
        j.value("event_path", "");

    record.timestamp =
        j.value("ts", "");

    record.embedding.reserve(
        j["embedding"].size()
    );

    for (const auto& value :
         j["embedding"])
    {
        if (value.is_number()) {
            record.embedding.push_back(
                value.get<double>()
            );
        }
    }

    if (record.embedding.empty()) {
        return std::nullopt;
    }

    return record;
}

std::size_t count_regular_files(
    const fs::path& directory
)
{
    std::error_code ec;

    if (
        !fs::exists(directory, ec) ||
        ec
    ) {
        return 0;
    }

    std::size_t count = 0;

    for (
        fs::directory_iterator it(
            directory,
            ec
        );
        !ec &&
        it != fs::directory_iterator();
        it.increment(ec)
    ) {
        if (it->is_regular_file()) {
            ++count;
        }
    }

    return count;
}

} // namespace

fs::path default_runtime_root()
{
    if (
        const char* configured =
            std::getenv(
                "NIFDU_BRAIN_RUNTIME"
            );
        configured &&
        *configured
    ) {
        return fs::path(configured);
    }

#ifdef _WIN32

    return fs::path(
        "C:/nifdu/runtime/brain"
    );

#else

    if (
        const char* home =
            std::getenv("HOME");
        home &&
        *home
    ) {
        return fs::path(home)
            / ".local"
            / "share"
            / "nifdu"
            / "brain";
    }

    return fs::temp_directory_path()
        / "nifdu"
        / "brain";

#endif
}

double cosine_similarity(
    const std::vector<double>& lhs,
    const std::vector<double>& rhs
)
{
    if (
        lhs.empty() ||
        rhs.empty()
    ) {
        return 0.0;
    }

    const std::size_t n =
        std::min(
            lhs.size(),
            rhs.size()
        );

    long double dot = 0.0;
    long double lhs_norm = 0.0;
    long double rhs_norm = 0.0;

    for (
        std::size_t i = 0;
        i < n;
        ++i
    ) {
        const long double x =
            lhs[i];

        const long double y =
            rhs[i];

        dot += x * y;
        lhs_norm += x * x;
        rhs_norm += y * y;
    }

    if (
        lhs_norm <= 0.0 ||
        rhs_norm <= 0.0
    ) {
        return 0.0;
    }

    return static_cast<double>(
        dot /
        (
            std::sqrt(lhs_norm) *
            std::sqrt(rhs_norm)
        )
    );
}

DiskMemory::DiskMemory(
    fs::path root
)
    : root_(
        root.empty()
            ? default_runtime_root()
            : std::move(root)
    )
{
    ensure_runtime_dirs(root_);
}

const fs::path&
DiskMemory::root() const noexcept
{
    return root_;
}

std::size_t
DiskMemory::reload_index() const
{
    const fs::path directory =
        root_ / "embeddings";

    std::vector<MemoryRecord>
        fresh;

    std::error_code ec;

    if (
        fs::exists(directory, ec) &&
        !ec
    ) {
        for (
            fs::directory_iterator it(
                directory,
                ec
            );
            !ec &&
            it != fs::directory_iterator();
            it.increment(ec)
        ) {
            if (!it->is_regular_file()) {
                continue;
            }

            const std::string name =
                it->path()
                  .filename()
                  .string();

            if (
                name.rfind(
                    "embedding_",
                    0
                ) != 0 ||
                it->path().extension()
                    != ".json"
            ) {
                continue;
            }

            auto record =
                parse_record(
                    it->path()
                );

            if (record) {
                fresh.push_back(
                    std::move(
                        *record
                    )
                );
            }
        }
    }

    {
        std::unique_lock lock(
            index_mutex_
        );

        index_ =
            std::move(fresh);

        index_loaded_ =
            true;

        return index_.size();
    }
}

void
DiskMemory::ensure_index_loaded() const
{
    {
        std::shared_lock lock(
            index_mutex_
        );

        if (index_loaded_) {
            return;
        }
    }

    reload_index();
}

Status DiskMemory::status() const
{
    Status result;

    result.root =
        root_;

    result.embeddings =
        count_regular_files(
            root_ /
            "embeddings"
        );

    result.queued =
        count_regular_files(
            root_ /
            "queue"
        );

    result.events =
        count_regular_files(
            root_ /
            "events"
        );

    {
        std::shared_lock lock(
            index_mutex_
        );

        result.index_loaded =
            index_loaded_;

        result.indexed_records =
            index_.size();
    }

    std::error_code ec;

    result.ok =
        fs::exists(
            root_,
            ec
        ) &&
        !ec;

    return result;
}

std::vector<SearchResult>
DiskMemory::search(
    const std::vector<double>& query_embedding,
    std::size_t top_k,
    const Scope& scope
) const
{
    std::vector<SearchResult>
        results;

    if (
        query_embedding.empty() ||
        top_k == 0
    ) {
        return results;
    }

    ensure_index_loaded();

    std::shared_lock lock(
        index_mutex_
    );

    results.reserve(
        std::min(
            index_.size(),
            top_k * 4
        )
    );

    for (const auto& record :
         index_)
    {
        if (
            !scope_matches(
                record,
                scope
            )
        ) {
            continue;
        }

        results.push_back({
            cosine_similarity(
                query_embedding,
                record.embedding
            ),
            record
        });
    }

    if (
        results.size() >
        top_k
    ) {
        std::partial_sort(
            results.begin(),
            results.begin() +
                static_cast<
                    std::ptrdiff_t
                >(top_k),
            results.end(),
            [](
                const SearchResult& lhs,
                const SearchResult& rhs
            ) {
                return lhs.score >
                       rhs.score;
            }
        );

        results.resize(top_k);
    } else {
        std::sort(
            results.begin(),
            results.end(),
            [](
                const SearchResult& lhs,
                const SearchResult& rhs
            ) {
                return lhs.score >
                       rhs.score;
            }
        );
    }

    return results;
}

std::string
DiskMemory::queue_query(
    const std::string& query,
    const Scope& scope
)
{
    if (query.empty()) {
        throw std::invalid_argument(
            "query must not be empty"
        );
    }

    ensure_runtime_dirs(root_);

    const std::string rid =
        make_rid();

    const fs::path event_path =
        root_
        / "events"
        / (
            "brain_query_" +
            rid +
            ".json"
        );

    const fs::path job_path =
        root_
        / "queue"
        / (
            "embed_" +
            rid +
            ".job.json"
        );

    const json event = {
        {"kind", "brain_query"},
        {"rid", rid},
        {"tenant", scope.tenant},
        {"user", scope.user},
        {"project", scope.project},
        {"query", query}
    };

    atomic_write_json(
        event_path,
        event
    );

    const json job = {
        {"kind", "embed"},
        {"rid", rid},
        {
            "event_path",
            event_path.string()
        },
        {"tenant", scope.tenant},
        {"user", scope.user},
        {"project", scope.project},
        {
            "surface",
            "brain_query"
        }
    };

    atomic_write_json(
        job_path,
        job
    );

    return rid;
}

} // namespace nifdu::brain
