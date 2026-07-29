# 🧩 NIFDU Development Status

_Last scanned: **2025-11-11 23:21:01**_

| Component | Status | Key Indicators |
|------------|---------|----------------|
| Studio Frontend (NifduRender) | ✅ Present | www, studio, C:\webroot\nifdu.com\www\studio | | Cloud & Ops (NifduOps) | ✅ Present | logs, build\out\nifdu.exe, services, win-acme, nssm | | Core Server (NifduServe) | ✅ Present | src\main.cpp, src\main_real.cpp, build, CMakeLists.txt | | Packager/Deployer (NifduPack) | ✅ Present | studio-deploy, deploy.py, projects | | Database Layer (NifduStack) | ✅ Present | config\nifdu.toml, schema, *.sql, postgres, pgvector | | AI Core (NifduDroid) | ✅ Present | ai, ai\serve.py, ai\api_lite.py | | Tool Connectors (NifduTools) | ❌ Missing | stripe, maps, twilio, tools, connectors |

## Overall Progress
**6 / 7 components complete → 85.7%**

---

### Auto-Update Behavior
This README is automatically refreshed whenever key directories or files change under C:\nifdu:
- src/, ai/, studio/, config/, deploy/, etc.
- Any time you run this script, or add/remove a component folder.


### LOC Snapshot (project) — 2025-11-11 23:48:17
Totals: 79 files • 8197 lines • 0.19 MB

Top files:
- ai\hf\transformers\hub\models--nomic-ai--nomic-embed-text-v1\snapshots\eb6b20cd65fcbdf7a2bc4ebac97908b3b21da981\README.md — 2819 lines
- src\main_real.cpp — 2035 lines
- src\main.cpp — 445 lines
- nifdu\nifdu.cpp — 280 lines
- C:\webroot\nifdu.com\www\studio\studio.js — 214 lines)

(Full report: C:\nifdu\reports\loc_project_report_20251111_234621.md)


### AI Model Switch — 2025-11-12 00:31:30
- Set **Qwen 7B Instruct (GGUF, Q4_K*)** via llama-cpp-python at **http://127.0.0.1:8091**
- Service: **nifdu-ai-qwen-8091**
- Model file: **C:\models\qwen2.5-7b-instruct-q4_k_m-00001-of-00002.gguf**
- Patched **C:\nifdu\config\nifdu.toml** → [ai].base_url=http://127.0.0.1:8091/v1 (provider=openai)

