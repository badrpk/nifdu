#ifndef NIFDU_SPIKING_WEIGHT_IMPORTER_HPP
#define NIFDU_SPIKING_WEIGHT_IMPORTER_HPP

#include <vector>
#include <string>
#include <unordered_map>
#include "nifdu/neuron_engine.hpp"

namespace nifdu {

struct TokenSpikeMapping {
    std::string token;
    int token_id;
    std::vector<double> spike_frequency_pattern;
};

class SpikingWeightImporter {
public:
    SpikingWeightImporter(int vocab_size = 32000, int hidden_dim = 512);
    
    // Convert trained dense weight matrices into LIF spiking synaptic connection weights
    bool import_from_dense_weights(const std::vector<float>& dense_weights, int rows, int cols);
    
    // STDP (Spike-Timing-Dependent Plasticity) Natural Language Training Pass
    void train_stdp_on_text(const std::string& text_corpus, int epochs = 5);
    
    // Predict next token using LIF spiking frequency activation
    std::string predict_next_token_spiking(const std::string& prompt);

private:
    int vocab_size_;
    int hidden_dim_;
    std::unordered_map<std::string, TokenSpikeMapping> vocab_map_;
    std::vector<std::string> id_to_token_;
    std::vector<std::vector<double>> stdp_synaptic_matrix_;
};

} // namespace nifdu

#endif // NIFDU_SPIKING_WEIGHT_IMPORTER_HPP
