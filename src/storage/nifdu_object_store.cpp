#include "storage/nifdu_object_store.hpp"
#include <iostream>

namespace nifdu {
namespace storage {

void init_object_store(const std::string& root_path) {
    // TODO: Map to real directory layout + metadata.
    std::cout << "[NIFDU::ObjectStore] STUB init at " << root_path << std::endl;
}

bool put_object(const std::string& bucket,
                const std::string& key,
                const std::string& data) {
    // TODO: Persist to disk, update indexes.
    std::cout << "[NIFDU::ObjectStore] STUB put " << bucket << "/" << key
              << " (" << data.size() << " bytes)" << std::endl;
    return true;
}

bool get_object(const std::string& bucket,
                const std::string& key,
                std::string& out) {
    // TODO: Load from disk.
    std::cout << "[NIFDU::ObjectStore] STUB get " << bucket << "/" << key << std::endl;
    out.clear();
    return false;
}

std::vector<ObjectInfo> list_objects(const std::string& bucket) {
    std::cout << "[NIFDU::ObjectStore] STUB list " << bucket << std::endl;
    return {};
}

} // namespace storage
} // namespace nifdu
