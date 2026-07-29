# Neuron source of truth

Authoritative SNN / STDP implementation:
  https://github.com/badrpk/neuron

NIFDU keeps **compatibility copies** of:
- `src/spiking_weight_importer.cpp`
- `include/nifdu/spiking_weight_importer.hpp`

These are refreshed from Neuron when content matches. They exist only so NIFDU
tests/targets that `#include "nifdu/spiking_weight_importer.hpp"` still build.

Migration (unique ownership):
1. Neuron exports a CMake library target.
2. NIFDU links that library.
3. NIFDU drops the compatibility copies.
