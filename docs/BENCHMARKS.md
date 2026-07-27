# NIFDU Benchmark Programme

This document records reproducible product-generation results for NIFDU and, where available, a small LangGraph comparison workflow.

## Fairness rules

Every direct comparison should use:

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
| 2 | Spreadsheet engine | Formula parsing, dependency recalculation, circular-reference handling, editing, persistence and CSV |
| 3 | Snake game | Animation, game state, collision rules, scoring, restart and touch controls |
| 4 | Synonym quiz | Question flow, answer checking, feedback, scoring and replay |
| 5 | Kanban board | Create, update, delete, drag-and-drop, filtering and persistence |
| 6 | Markdown editor | Editing, live preview, formatting and persistence |
| 7 | Chess game | Rule complexity, move validation, turn state and interface quality |
| 8 | Drawing application | Canvas input, tools, undo, clear and export |
| 9 | Weather dashboard | API use, loading state, failure handling and responsive presentation |
| 10 | Expense tracker | Forms, calculations, categories, charts and persistence |

## Recorded result: Scientific calculator

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

## Recorded result: Spreadsheet engine

Prompt summary:

> Build a compact self-contained browser spreadsheet in one HTML file with a 30-row by 20-column editable grid, cell references, arithmetic formulas, SUM, AVERAGE, MIN, MAX, IF, dependent-cell recalculation, circular-reference detection, copy, paste, delete, undo, CSV import/export, local autosave, mobile controls and at least 20 built-in automated tests.

Environment:

- Android Termux
- Gemini 3.6 Flash builder and independent judge
- NIFDU Termux fast mode
- Maximum two quality loops
- Large-product continuation protection enabled

Result:

| System | Iterations | Critical issues | Unmet requirements | Judge score | Outcome |
|---|---:|---:|---:|---:|---|
| NIFDU | **1** | **0** | **0** | **92/100** | Accepted |
| LangGraph workflow | Not yet run | — | — | — | Pending |

The independent judge reported that the generated single-file spreadsheet included a custom formula engine with range support and error handling, local save/load, CSV import/export, formatting tools, column resizing, keyboard navigation, status statistics and a canvas chart generator.

A manual Android-browser check confirmed that the spreadsheet rendered correctly with its grid, formula bar, mobile toolbar, sample budget data, formatting controls and CSV controls visible and usable.

This result is recorded as a NIFDU product-generation result, not yet as a direct NIFDU-versus-LangGraph victory because the equivalent LangGraph run remains pending.

## Recorded result: Offline Kanban board

Prompt summary:

> Build a production-quality offline Kanban project-management application in one self-contained HTML file with multiple projects, five workflow columns, full task CRUD, duplication, drag-and-drop and reordering, task metadata, search and filtering, progress statistics, activity history, undo/redo, local autosave, JSON import/export, keyboard shortcuts, mobile touch controls, accidental-data-loss protection, realistic sample data and at least 20 built-in automated self-tests.

Environment:

- Android Termux
- Gemini 3.6 Flash builder and independent judge
- NIFDU Termux fast mode
- Maximum two quality loops
- Large-product continuation protection enabled

Result:

| System | Iterations | Critical issues | Unmet requirements | Judge score | Outcome |
|---|---:|---:|---:|---:|---|
| NIFDU | **1** | **0** | **0** | **92/100** | Accepted |
| LangGraph workflow | Not yet run | — | — | — | Pending |

The independent judge described the generated app as a feature-complete offline Kanban system with project switching, customisable columns and WIP limits, drag-and-drop, task checklists and progress indicators, tag and priority filters, search, analytics, theme switching, and local data import/export.

This result is recorded as a NIFDU product-generation result. A direct LangGraph comparison for this prompt remains pending.

## Current NIFDU scorecard

| Completed task | Score | Accepted | First iteration |
|---|---:|---:|---:|
| Scientific calculator | 98/100 | Yes | Yes |
| Spreadsheet engine | 92/100 | Yes | Yes |
| Offline Kanban board | 92/100 | Yes | Yes |
| **Total** | **282/300** | **3/3** | **3/3** |

## Interpretation

The completed tests show that NIFDU can produce valid, high-scoring single-file browser applications on Android Termux. The spreadsheet and Kanban results also provide evidence that the large-product continuation changes addressed the earlier truncation failure for these workloads.

These results do **not** establish a universal performance advantage. A meaningful overall conclusion requires completion of the full ten-test suite, equivalent comparison runs and repeated trials to account for model variance and network latency.

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