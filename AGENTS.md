# AGENTS.md

## What this repo is

A collection of **coding-guideline documents**, not an application. There is no
source code, no build/test/lint tooling, no package manifest, and no git repo
here. Do not look for entrypoints, run test commands, or expect a toolchain.

Two files, with overlapping content:

- `copilot-instructions.md` — the authoritative, detailed ruleset (Python-oriented:
  module structure, naming, error handling, validation, logging, testing, commits).
- `CLAUDE.md` — a shorter behavioral subset (Think Before Coding, Simplicity First,
  Surgical Changes, Goal-Driven Execution). When both apply, `copilot-instructions.md`
  is the fuller source; keep the two consistent when editing either.

## Non-obvious conventions (would be missed otherwise)

- **Language split** (`copilot-instructions.md` §Communication & Language): all prose
  — docs, READMEs, inline comments, docstrings, chat/review — is written in **German**.
  Only code identifiers and commit messages are in **English**.
- **Commits:** atomic (one logical change each); conventional-commit style messages.
- **File naming in docs:** no version suffixes (`_final`, `_v2`, `_neu`); use
  `YYYY-MM-DD` (ISO 8601) for date-based names.
- Guidelines assume a **Python** codebase (stdlib-first, `dataclasses`/Pydantic over
  bare dicts, `logging` module never `print()`, type hints on all touched functions).

## Editing these files

Treat them as prose specs. Preserve the existing structure and the German/English
split above. When a rule changes in one file, reconcile the other so they don't drift.
