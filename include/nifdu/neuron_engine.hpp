#ifndef NIFDU_NEURON_ENGINE_HPP
#define NIFDU_NEURON_ENGINE_HPP

#include <vector>
#include <string>
#include <chrono>
#include <random>

namespace nifdu {

struct SpikingNeuron {
    double voltage = -70.0;          // Membrane potential (mV)
    double threshold = -55.0;        // Spike firing threshold (mV)
    double rest_potential = -70.0;   // Resting potential (mV)
    double decay_rate = 0.92;        // LIF Leak decay constant
    int refractory_counter = 0;      // Refractory period steps
    bool has_spiked = false;
    double fire_rate = 0.0;
};

struct SnnBenchmarkResult {
    uint64_t total_loops = 0;
    double elapsed_ms = 0.0;
    double spikes_per_sec = 0.0;
    double motor_entropy_bits = 0.0;
    double noise_robustness_pct = 0.0;
    std::string intelligence_type = "Biological Spiking LIF Dynamics (Non-Transformer)";
};

class NeuronEngine {
public:
    NeuronEngine(int sensory_count = 9, int hidden_count = 18, int motor_count = 9);
    
    void reset();
    void set_sensory_input(const std::vector<double>& inputs);
    void step_simulation();
    
    SnnBenchmarkResult run_million_loops_benchmark(uint64_t num_loops = 1000000);
    
    std::vector<double> get_motor_outputs() const;
    std::vector<double> get_hidden_voltages() const;
    double get_synaptic_weight(int from, int to) const;

private:
    int sensory_n_;
    int hidden_n_;
    int motor_n_;
    
    std::vector<SpikingNeuron> sensory_neurons_;
    std::vector<SpikingNeuron> hidden_neurons_;
    std::vector<SpikingNeuron> motor_neurons_;
    
    std::vector<std::vector<double>> sensory_to_hidden_weights_;
    std::vector<std::vector<double>> hidden_to_motor_weights_;
    
    std::mt19937 rng_;
};

} // namespace nifdu

#endif // NIFDU_NEURON_ENGINE_HPP
