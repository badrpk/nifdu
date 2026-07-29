#include "nifdu/spiking_weight_importer.hpp"
#include <cmath>
#include <sstream>
#include <iostream>
#include <algorithm>

namespace nifdu {

SpikingWeightImporter::SpikingWeightImporter(int vocab_size, int hidden_dim)
    : vocab_size_(vocab_size), hidden_dim_(hidden_dim)
{
    stdp_synaptic_matrix_.assign(1000, std::vector<double>(1000, 0.1));
}

bool SpikingWeightImporter::import_from_dense_weights(const std::vector<float>& dense_weights, int rows, int cols) {
    if (dense_weights.empty()) return false;
    
    // Map floating-point dense attention weights into LIF spike threshold / synaptic weights: W_snn = tanh(W_dense)
    int count = 0;
    for (int r = 0; r < rows && r < 1000; ++r) {
        for (int c = 0; c < cols && c < 1000; ++c) {
            float w = dense_weights[r * cols + c];
            stdp_synaptic_matrix_[r][c] = std::tanh(w) * 0.8;
            count++;
        }
    }
    return count > 0;
}

void SpikingWeightImporter::train_stdp_on_text(const std::string& text_corpus, int epochs) {
    std::stringstream ss(text_corpus);
    std::string word;
    std::vector<std::string> tokens;
    
    while (ss >> word) {
        tokens.push_back(word);
        if (std::find(id_to_token_.begin(), id_to_token_.end(), word) == id_to_token_.end()) {
            id_to_token_.push_back(word);
        }
    }
    
    // STDP (Spike-Timing-Dependent Plasticity) Weight Adjustment Loop: Delta_W = A * exp(-Delta_t / tau)
    for (int ep = 0; ep < epochs; ++ep) {
        for (size_t i = 0; i + 1 < tokens.size(); ++i) {
            auto it1 = std::find(id_to_token_.begin(), id_to_token_.end(), tokens[i]);
            auto it2 = std::find(id_to_token_.begin(), id_to_token_.end(), tokens[i+1]);
            if (it1 != id_to_token_.end() && it2 != id_to_token_.end()) {
                int id1 = std::distance(id_to_token_.begin(), it1) % 1000;
                int id2 = std::distance(id_to_token_.begin(), it2) % 1000;
                
                // STDP Potentiation
                stdp_synaptic_matrix_[id1][id2] += 0.05 * std::exp(-1.0 / 20.0);
            }
        }
    }
}

std::string SpikingWeightImporter::predict_next_token_spiking(const std::string& prompt) {
    std::stringstream ss(prompt);
    std::string word, last_word;
    while (ss >> word) last_word = word;
    
    auto it = std::find(id_to_token_.begin(), id_to_token_.end(), last_word);
    if (it != id_to_token_.end()) {
        int id1 = std::distance(id_to_token_.begin(), it) % 1000;
        int max_id = 0;
        double max_w = -1.0;
        for (int j = 0; j < (int)id_to_token_.size() && j < 1000; ++j) {
            if (stdp_synaptic_matrix_[id1][j] > max_w) {
                max_w = stdp_synaptic_matrix_[id1][j];
                max_id = j;
            }
        }
        if (max_id < (int)id_to_token_.size()) {
            return id_to_token_[max_id];
        }
    }
    
    return "intelligence";
}

} // namespace nifdu
