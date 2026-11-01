# Tests

A small CC:Tweaked simulator (`mock.lua` + `harness.py`, Python + `lupa`) runs scenarios
(`t_*.lua`) against the repository. Run `tests/run_all.sh` from the repo root.
Known harmless noise: `/lib/specs.lua` errors and "not a peripheral".
Scenarios using `shell` inside dofile'd libraries show harness-only errors (no `shell` global).
