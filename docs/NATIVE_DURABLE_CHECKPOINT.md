# Native durable checkpoints

Sophyane owns thread_id / interrupt / resume in Python
(`sophyane.lc_compat.durable_graph`).

NIFDU may mirror checkpoint blobs under:
  ~/.local/state/sophyane/checkpoints/native/

Contract (JSON file per thread):
  { "thread_id", "step", "payload": {...}, "updated_at" }

Do not re-implement prompt templates, datasets, or LangSmith UI in NIFDU.
