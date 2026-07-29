#ifndef NIFDU_SIMD_DATA_ENGINE_HPP
#define NIFDU_SIMD_DATA_ENGINE_HPP

#include <vector>
#include <string>
#include <cmath>
#include <limits>
#include <nlohmann/json.hpp>

namespace nifdu {

using json = nlohmann::json;

struct DataSummary {
    size_t total_count = 0;
    size_t valid_count = 0;
    size_t nan_count = 0;
    double mean = 0.0;
    double min_val = std::numeric_limits<double>::infinity();
    double max_val = -std::numeric_limits<double>::infinity();
    double std_dev = 0.0;
};

class SimdDataEngine {
public:
    // Sub-millisecond SIMD Data Vector Processing Engine
    static DataSummary process_array(const std::vector<double>& input_data);
    static json process_json_dataset(const std::string& json_str);
    static json execute_expression(const std::string& column_name, const std::vector<double>& input_data, const std::string& op);
};

} // namespace nifdu

#endif // NIFDU_SIMD_DATA_ENGINE_HPP
