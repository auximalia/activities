# AGENTS.md

*Stand: v1.19.35 · 2026-08-10*

## What this repo is

The macOS app **activities** — a SwiftUI/AppKit tool that shows which folders were
worked in recently. Swift package plus an xcodegen spec; the guideline documents
live alongside the code.

```
Sources/ActivitiesCore/   pure domain logic, Foundation only, no SwiftUI — testable
Sources/activities/       the SwiftUI app (Views/, Style/, Services/)
Sources/CoreChecks/       assertion runner for the domain logic (see below)
Tests/ActivitiesCoreTests XCTest suite — needs full Xcode
Packaging/                build_app.sh, release.sh, web-install.sh, assets
backlog.md                the record of decisions — read this before changing UI
```

## Two gates: ask before building, ship without asking

These two rules look opposed. They are not — they sit at opposite ends of the work.

**Before implementation: wait for explicit approval.** Planning, code review, cutting
a sprint, writing tickets, measuring, answering questions — all of that proceeds
freely. **Writing production code does not.** Present the plan, name the trade-offs,
then stop and wait for a clear go. "Shall we continue?" is not a go. Approval is a
decision about *what* gets built and is the user's alone; an agent that starts coding
during the planning conversation has taken that decision away.

**After implementation: release without asking.** Once the work is finished and
checked (`swift build`, `swift run CoreChecks`), ship it with `release.sh`. Do not
ask for permission to release — that decision was already made when the work was
approved.

So: **approval opens the gate, completion closes it.** Asking in the middle is
friction; asking at the start is respect.

Exception at both gates: a defect that hurts the user in the field. Fix and ship.

## Build, check, release

```
swift build            # compiles core + app
swift run CoreChecks   # runs the domain assertions (the check that always works)
swift test             # XCTest — FAILS with Command Line Tools only, needs full Xcode
./Packaging/release.sh "commit message"
```

`release.sh` does everything in one go: bumps the patch number in `VERSION`, stamps
the Markdown documents changed in this release, commits, builds a universal bundle,
installs it to `/Applications`, creates the ZIP, pushes, and cuts a GitHub release.

⚠️ `release.sh` runs `git add -A` — anything uncommitted in the tree, including the
user's own scratch notes, goes into that commit. Check `git status` first.

⚠️ A pure planning or documentation change does **not** go through `release.sh`. It
has no effect on the user and does not deserve a version number; commit and push it
plainly. See the sprint-scope rule below.

## Sprint scope: do not ship changes smaller than their own release

**⚠️ A change of a few lines must not get its own build-and-push cycle.** The
release run — universal build, install, ZIP, push, GitHub release — takes longer
than such a change itself, and each one costs a version number, a stamped document
and an entry in the history. That is a bad trade: the ceremony outweighs the work.

Therefore:

- A sprint carries **at least one substantial item** (M or L) that justifies the
  release on its own.
- Small items (S) ride along in that sprint instead of getting their own. Note them
  in the sprint cut as *Beifahrer* with the reason, so it is visible that they were
  deliberately bundled and not forgotten.
- If only small items are pending, collect them until a substantial one joins —
  unless something is broken for the user, which ships immediately.
- The exception is a fix for a defect in the field. Correctness never waits for a
  travel companion.

The current cut is at the end of `backlog.md` under the highest-numbered `## Sprint N`
heading. Do not hard-code the number here — it went stale five sprints in a row.

## The guideline documents

- `copilot-instructions.md` — the fuller ruleset (module structure, naming, error
  handling, validation, logging, testing, commits). Written for Python; read the
  *principles*, not the language specifics.
- `CLAUDE.md` — a shorter behavioural subset (Think Before Coding, Simplicity First,
  Surgical Changes, Goal-Driven Execution).

When a rule changes in one, reconcile the other so they do not drift.

## Conventions that would otherwise be missed

- **Language split:** all prose — documentation, comments, doc comments, chat — is
  **German**. Code identifiers and commit messages are **English**. This file and the
  two guideline documents are the exception; they are agent-facing meta and stay
  English.
- **Measure, do not estimate.** Colour, contrast and column widths are decided by
  measurement, and the number goes into the doc comment next to the value. There are
  three separate lessons in `backlog.md` from getting this wrong (UX-12, PR-31,
  PR-33). If you are about to write "looks about right", write a small script instead.
- **`backlog.md` is the record.** Every non-trivial change gets an entry with the
  finding, what was done, and what was deliberately *not* done. Entries carry the
  version in which they shipped.
- **Commits:** atomic, conventional-commit style. The message says what was found,
  not only what was changed.
- **Doc comments carry the reason, not the restatement.** `⚠️` marks a decision that
  looks wrong until you know why — those paragraphs exist to stop the next person
  from "fixing" it back.
- **Domain logic belongs in `ActivitiesCore`.** If a rule cannot be reached by
  `CoreChecks`, it will drift unnoticed — that is exactly how the timestamp
  formatting fell apart before PR-32.
- **File naming in docs:** no version suffixes (`_final`, `_v2`, `_neu`); use
  `YYYY-MM-DD` (ISO 8601) for date-based names.
