# NIFDU — Autonomous C++20 AI Product Builder

<p align="center">
  <img src="https://img.shields.io/badge/C%2B%2B-20-00599C?style=for-the-badge&logo=cplusplus&logoColor=white" alt="C++20"/>
  <img src="https://img.shields.io/badge/Termux-Ready-10B981?style=for-the-badge&logo=android&logoColor=white" alt="Termux Ready"/>
  <img src="https://img.shields.io/badge/Gemini-Autonomous%20Build-6366F1?style=for-the-badge" alt="Gemini Autonomous Build"/>
  <img src="https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge" alt="MIT License"/>
</p>

## What NIFDU does

NIFDU is a native C++20 autonomous product builder. Give it a plain-English request and it will:

1. generate a complete browser application;
2. launch a local preview;
3. evaluate the result with an independent AI judge;
4. repair the product when required;
5. save the final HTML and a JSON evaluation report.

It is designed to run directly on Linux and Android through Termux, without requiring a heavy Python agent runtime for its main product loop.

## Verified examples

Recent Termux runs produced these accepted applications:

| Product | Judge score | Iterations | Result |
|---|---:|---:|---|
| Scientific calculator | **96/100** | 1 | Accepted |
| Snake game | **95/100** | 1 | Accepted |

The generated calculator included scientific functions, history, memory controls, keyboard support and a responsive mobile interface. The generated Snake game included multiple modes, mobile controls, scoring and persistent statistics.

## NIFDU vs LangGraph: first reproducible product test

A blind benchmark used the same Gemini model and the same scientific-calculator prompt for both systems.

| System | Time | Valid product | Blind judge score |
|---|---:|---:|---:|
| **NIFDU** | 96.5 s | Yes | **98/100** |
| LangGraph workflow | 77.5 s | No | 0/100 |

**Winner for this test: NIFDU.**

The LangGraph workflow completed faster but returned no valid implementation. This is one recorded product-generation test, not a universal claim that NIFDU is faster or better for every workload. The full 10-test suite and methodology are documented in [`docs/BENCHMARKS.md`](docs/BENCHMARKS.md).

## Termux fast mode

On Android, headless Chromium capture can be unreliable and slow. NIFDU detects Termux and skips those screenshot attempts while preserving:

- local browser preview;
- HTML evidence collection;
- independent judging;
- repair iterations;
- final product and report generation.

Current Termux defaults use a maximum of two quality loops, allowing good products to finish quickly while still giving the repair stage one additional opportunity.

## One-line installation

### Termux, Linux and macOS

```bash
curl -fsSL https://raw.githubusercontent.com/badrpk/nifdu/master/install-nifdu.sh | bash
```

Then run:

```bash
nifdu
```

Example request:

```text
Create a polished responsive scientific calculator with history, keyboard support and mobile controls.
```

## Build from source

```bash
git clone https://github.com/badrpk/nifdu.git
cd nifdu
cmake -S . -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_TESTING=OFF
cmake --build build --target nifdu --parallel
./build/nifdu
```

## Output

Each run creates a workspace such as:

```text
~/nifdu-workspaces/product-YYYYMMDD-HHMMSS/
├── product/index.html
└── final-report.json
```

The generated product can be served locally with:

```bash
cd ~/nifdu-workspaces/product-YYYYMMDD-HHMMSS/product
python3 -m http.server 8080 --bind 127.0.0.1
```

Open `http://127.0.0.1:8080` in the browser.

## Planned 10-test comparison

The benchmark suite covers:

1. scientific calculator;
2. Snake game;
3. synonym quiz;
4. 900-word news editor;
5. Kanban board;
6. Markdown editor;
7. chess game;
8. drawing application;
9. weather dashboard;
10. expense tracker.

Results will report total score, average score, first-attempt passes, average build time and invalid-output count.

## Why try NIFDU

- Native C++20 executable
- Runs on Android through Termux
- Plain-English product generation
- Automatic AI judging and repair
- Immediate local preview
- Self-contained HTML output
- Reproducible JSON reports
- Open-source MIT licence

## Contributing

Bug reports, benchmark improvements, installation fixes and product-generation tests are welcome through GitHub issues and pull requests.

## Licence

MIT License. Copyright © 2026 NIFDU Product Engine.
