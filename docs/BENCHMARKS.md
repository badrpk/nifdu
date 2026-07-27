# NIFDU Benchmark Programme

This document records the reproducible product-generation comparison between NIFDU and a small LangGraph workflow.

## Fairness rules

Every test should use:

- the same Gemini model;
- the same product prompt;
- the same maximum number of generation attempts;
- the same independent blind judge;
- the same scoring rubric;
- the same device and network where practical.

LangGraph is an orchestration framework rather than a complete product builder. The comparison therefore uses a minimal LangGraph graph that generates an application, checks document completeness and retries once when necessary.

## Scoring rubric

Each product is scored out of 100:

| Category | Points |
|---|---:|
| Functional correctness | 40 |
| Requirement coverage | 25 |
| Mobile usability | 15 |
| Code completeness and reliability | 10 |
| Visual quality | 10 |

A fatal HTML or JavaScript failure must score below 50.

## Ten-test suite

| # | Product task | Main capabilities tested |
|---|---|---|
| 1 | Scientific calculator | Mathematical correctness, scientific functions, history, keyboard and mobile controls |
| 2 | Snake game | Animation, game state, collision rules, scoring, restart and touch controls |
| 3 | Synonym quiz | Question flow, answer checking, feedback, scoring and replay |
| 4 | 900-word news editor | Word count, progress, copy, clear and local autosave |
| 5 | Kanban board | Create, update, delete, drag-and-drop and persistence |
| 6 | Markdown editor | Editing, live preview, formatting and persistence |
| 7 | Chess game | Rule complexity, move validation, turn state and interface quality |
| 8 | Drawing application | Canvas input, tools, undo, clear and export |
| 9 | Weather dashboard | API use, loading state, failure handling and responsive presentation |
| 10 | Expense tracker | Forms, calculations, categories, charts and persistence |

## Recorded result: Test 1

Prompt:

> Create a polished responsive scientific calculator in one self-contained HTML file with history, keyboard support and mobile controls.

Environment:

- Android Termux
- Gemini 3.6 Flash configured for both builders and the blind judge
- NIFDU Termux fast mode
- Maximum two quality loops

Result:

| System | Elapsed time | Valid HTML | Blind judge score | Outcome |
|---|---:|---:|---:|---|
| NIFDU | 96.5 seconds | Yes | **98/100** | Winner |
| LangGraph workflow | 77.5 seconds | No | 0/100 | No implementation produced |

Judge reason:

> Candidate A fulfilled all requirement criteria with exceptional UI polish, functional accuracy, responsive mobile layout, and complete keyboard controls. Candidate B submitted no implementation.

The generated NIFDU calculator was then served locally and manually checked in a mobile browser. A sample calculation, `95 × 65`, returned `6175`, and the responsive scientific interface loaded successfully.

## Interpretation

This result demonstrates that NIFDU decisively won the first tested product-generation task on completeness and judged quality. LangGraph completed its orchestration sooner, but its candidate was invalid.

This single test does **not** establish a universal performance advantage. A meaningful overall conclusion requires completion of the full ten-test suite and repeated runs to account for model variance and network latency.

## Final report format

After all ten tests, publish:

- total score out of 1,000;
- average judge score;
- valid-product rate;
- first-attempt acceptance count;
- average build time;
- median build time;
- invalid or truncated output count;
- per-test winner;
- raw JSON reports.

## Reproduction notes

The local benchmark runner is expected under:

```text
benchmarks/nifdu-vs-langgraph/
```

A valid Gemini API key must be supplied locally. Never commit API keys, generated credentials or private benchmark configuration to the repository.
