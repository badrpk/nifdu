#pragma once

#include <map>
#include <string>
#include <vector>

namespace nifdu {

struct EvidenceManifest {
    std::string url;
    int viewport_width{0};
    int viewport_height{0};
    std::string dom_sha256;
    std::string render_sha256;
    std::string screenshot_sha256;
    int console_error_count{0};
    std::map<std::string, std::string> metadata;
};

struct EvidenceDiff {
    bool viewport_changed{false};
    bool dom_changed{false};
    bool render_changed{false};
    bool screenshot_changed{false};
    int console_error_delta{0};
    std::vector<std::string> changed_metadata_keys;

    bool has_regression() const;
};

bool is_sha256_hex(const std::string& value);
void validate_evidence_manifest(const EvidenceManifest& manifest);
std::string canonical_evidence(const EvidenceManifest& manifest);
std::string evidence_id(const EvidenceManifest& manifest);
EvidenceDiff compare_evidence(const EvidenceManifest& before,
                              const EvidenceManifest& after);

}  // namespace nifdu
