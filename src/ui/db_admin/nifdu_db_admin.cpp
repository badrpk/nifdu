#include "ui/db_admin/nifdu_db_admin.hpp"

namespace nifdu {
namespace ui {
namespace db_admin {

std::string render_dashboard_html() {
    // TODO: Generate real HTML from live DB stats.
    return "<h1>NIFDU DB Admin (stub)</h1>";
}

std::string render_table_view(const std::string& table) {
    return "<h2>Table: " + table + " (stub)</h2>";
}

} // namespace db_admin
} // namespace ui
} // namespace nifdu
