#include "nifdu/evidence_manifest.hpp"

#include <algorithm>
#include <cctype>
#include <iomanip>
#include <set>
#include <sstream>
#include <stdexcept>

namespace nifdu {
namespace {

std::string fnv1a64_hex(const std::string& input) {
    unsigned long long hash = 1469598103934665603ULL;
    for (unsigned char c : input) {
        hash ^= static_cast<unsigned long long>(c);
        hash *= 1099511628211ULL;
    }
    std::ostringstream out;
    out << std::hex << std::setfill('0') << std::setw(16) << hash;
    return out.str();
}

std::string escape_field(const std::string& value) {
    std::ostringstream out;
    for (unsigned char c : value) {
        if (c == '\\' || c == '=' || c == ';' || c == '\n' || c == '\r') {
            out << '\\';
        }
        out << static_cast<char>(c);
    }
    return out.str();
}

}  // namespace

bool EvidenceDiff::has_regression() const {
    return viewport_changed || dom_changed || render_changed || screenshot_changed ||
           console_error_delta > 0 || !changed_metadata_keys.empty();
}

bool is_sha256_hex(const std::string& value) {
    if (value.size() != 64) {
        return false;
    }
    return std::all_of(value.begin(), value.end(), [](unsigned char c) {
        return std::isxdigit(c) != 0;
    });
}

void validate_evidence_manifest(const EvidenceManifest& manifest) {
    if (manifest.url.empty()) {
        throw std::invalid_argument("evidence url must not be empty");
    }
    if (manifest.viewport_width <= 0 || manifest.viewport_height <= 0) {
        throw std::invalid_argument("viewport dimensions must be positive");
    }
    if (!is_sha256_hex(manifest.dom_sha256) ||
        !is_sha256_hex(manifest.render_sha256) ||
        !is_sha256_hex(manifest.screenshot_sha256)) {
        throw std::invalid_argument("evidence hashes must be 64-character hex SHA-256 values");
    }
    if (manifest.console_error_count < 0) {
        throw std::invalid_argument("console error count must not be negative");
    }
    for (const auto& [key, value] : manifest.metadata) {
        if (key.empty()) {
            throw std::invalid_argument("metadata keys must not be empty");
        }
        (void)value;
    }
}

std::string canonical_evidence(const EvidenceManifest& manifest) {
    validate_evidence_manifest(manifest);
    std::ostringstream out;
    out << "url=" << escape_field(manifest.url) << ';'
        << "viewport=" << manifest.viewport_width << 'x' << manifest.viewport_height << ';'
        << "dom=" << manifest.dom_sha256 << ';'
        << "render=" << manifest.render_sha256 << ';'
        << "screenshot=" << manifest.screenshot_sha256 << ';'
        << "console_errors=" << manifest.console_error_count << ';';

    for (const auto& [key, value] : manifest.metadata) {
        out << "meta." << escape_field(key) << '=' << escape_field(value) << ';';
    }
    return out.str();
}

std::string evidence_id(const EvidenceManifest& manifest) {
    // Deterministic compact evidence identifier. Content SHA-256 values remain
    // recorded verbatim in the manifest; this ID is only a stable local key.
    return "nifdu-evidence-" + fnv1a64_hex(canonical_evidence(manifest));
}

EvidenceDiff compare_evidence(const EvidenceManifest& before,
                              const EvidenceManifest& after) {
    validate_evidence_manifest(before);
    validate_evidence_manifest(after);

    EvidenceDiff diff;
    diff.viewport_changed = before.viewport_width != after.viewport_width ||
                            before.viewport_height != after.viewport_height;
    diff.dom_changed = before.dom_sha256 != after.dom_sha256;
    diff.render_changed = before.render_sha256 != after.render_sha256;
    diff.screenshot_changed = before.screenshot_sha256 != after.screenshot_sha256;
    diff.console_error_delta = after.console_error_count - before.console_error_count;

    std::set<std::string> keys;
    for (const auto& item : before.metadata) keys.insert(item.first);
    for (const auto& item : after.metadata) keys.insert(item.first);
    for (const auto& key : keys) {
        const auto lhs = before.metadata.find(key);
        const auto rhs = after.metadata.find(key);
        if (lhs == before.metadata.end() || rhs == after.metadata.end() || lhs->second != rhs->second) {
            diff.changed_metadata_keys.push_back(key);
        }
    }
    return diff;
}

}  // namespace nifdu
