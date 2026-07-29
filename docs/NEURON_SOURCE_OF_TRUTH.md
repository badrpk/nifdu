# Neuron source of truth

Spiking / LIF / STDP implementation lives in:
  https://github.com/badrpk/neuron  (local: /home/badrpk/neuron_repo)

NIFDU must not keep a second full copy of the same sources.
Integration options:
  1. Link/call Neuron binary (SOPHYANE_NEURON_BIN / test_neuron_capabilities)
  2. Optional CMake FetchContent / submodule of badrpk/neuron
  3. Thin adapter only inside nifdu (no duplicated engine bodies)

Priority if files were identical: keep Neuron, drop NIFDU copy.
