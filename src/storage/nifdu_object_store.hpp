#pragma once

#include <string>
#include <vector>

namespace nifdu {
namespace storage {

struct ObjectInfo {
    std::string bucket;
    std::string key;
    std::size_t size_bytes = 0;
};

void init_object_store(const std::string& root_path);
bool put_object(const std::string& bucket,
                const std::string& key,
                const std::string& data);
bool get_object(const std::string& bucket,
                const std::string& key,
                std::string& out);
std::vector<ObjectInfo> list_objects(const std::string& bucket);

} // namespace storage
} // namespace nifdu
