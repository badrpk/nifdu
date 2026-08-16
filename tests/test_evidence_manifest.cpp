#include "nifdu/evidence_manifest.hpp"

#include <cassert>
#include <stdexcept>
#include <string>

using nifdu::EvidenceManifest;

static std::string h(char c) {
    return std::string(64, c);
}

int main() {
    EvidenceManifest base{
        "https://example.test/page",
        1280,
        720,
        h('a'),
        h('b'),
        h('c'),
        0,
        {{"browser", "chromium"}, {"theme", "light"}},
    };

    nifdu::validate_evidence_manifest(base);
    const auto canonical1 = nifdu::canonical_evidence(base);
    const auto canonical2 = nifdu::canonical_evidence(base);
    assert(canonical1 == canonical2);
    assert(nifdu::evidence_id(base) == nifdu::evidence_id(base));

    auto same = nifdu::compare_evidence(base, base);
    assert(!same.has_regression());
    assert(same.console_error_delta == 0);

    auto changed = base;
    changed.render_sha256 = h('d');
    changed.screenshot_sha256 = h('e');
    changed.console_error_count = 2;
    changed.metadata["theme"] = "dark";

    const auto diff = nifdu::compare_evidence(base, changed);
    assert(diff.render_changed);
    assert(diff.screenshot_changed);
    assert(diff.console_error_delta == 2);
    assert(diff.changed_metadata_keys.size() == 1);
    assert(diff.changed_metadata_keys.front() == "theme");
    assert(diff.has_regression());

    auto bad = base;
    bad.dom_sha256 = "not-a-sha";
    bool threw = false;
    try {
        nifdu::validate_evidence_manifest(bad);
    } catch (const std::invalid_argument&) {
        threw = true;
    }
    assert(threw);

    bad = base;
    bad.viewport_width = 0;
    threw = false;
    try {
        nifdu::validate_evidence_manifest(bad);
    } catch (const std::invalid_argument&) {
        threw = true;
    }
    assert(threw);

    bad = base;
    bad.console_error_count = -1;
    threw = false;
    try {
        nifdu::validate_evidence_manifest(bad);
    } catch (const std::invalid_argument&) {
        threw = true;
    }
    assert(threw);

    return 0;
}
