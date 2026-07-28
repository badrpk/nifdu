# Native C++ graph control plane

NIFDU 2.1 introduces a native C++20 control-plane entrypoint in front of the existing product engine.

## Runtime graph

```text
user_task
  -> policy_gate
  -> planner
  -> builder
  -> validator
  -> judge
  -> preview or final
```

The validator and judge may route execution back to the builder for repair. The launcher computes an authorised graph path, rejects explicitly destructive requests, injects the execution contract into the immutable customer prompt and writes JSON traces under:

```text
~/.local/share/nifdu/control-plane/traces/
```

## Commands

```bash
nifdu --graph-status
nifdu "Build a responsive calculator"
nifdu --raw "Build without the graph launcher"
```

`nifdu` is the graph-controlled executable. `nifdu-core` contains the existing autonomous builder and judge loop.

## Scope

This first version enforces policy and workflow admission at the native process boundary and supplies an auditable control contract to the core. A later refactor can move every builder, validator, judge and preview transition into the same state machine for tool-level enforcement inside the core process.
