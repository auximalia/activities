# AGENTS.md

*Stand: v1.19.49 · 2026-08-11*

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

## Two skills that must actually be run

Both of these existed and were skipped on the day they were needed. A skill nobody
invokes is worse than no skill: it creates the impression the check happened.

**Before implementing a decision that is user-visible or hard to reverse — run
`decision-check`.** Where a control belongs, what it is called, whether a rule is
enforced at the boundary or repaired downstream, whether state is persisted. The
trigger is simple: *if the decision would earn a `⚠️` doc comment, it earns the
check first.*

**Before shipping anything with a visible change — run `ux-review`.** Not only when
asked for a review. It reads the running app through the eyes of someone who did not
build it, which is exactly the eye the author has lost.

⚠️ **An exception forced in another component is a finding, not a footnote.** If a
placement or a responsibility makes some *other* part break its own documented rule,
that is evidence the decision is wrong. The `⚠️` convention protects good decisions
from being "fixed" back — it also makes bad ones look considered. Writing a
justification is not the same as testing one.

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

## Release rhythm: sprints are over, small changes are the mode

**⚠️ This section reversed on 2026-08-11, and the reason matters more than the rule.**
It used to say: *a change of a few lines must not get its own build-and-push cycle*,
because the release run costs a version number, a stamped document and a history
entry, and for a two-line change the ceremony outweighs the work. **That argument was
right and is now moot** — it assumed there is a queue of substantial work to bundle
small changes into. There is not. The owner declared the product done in these words:
*„Die App ist gut, wie sie ist."* The open list holds no M and no L that is not
deliberately deferred.

When nothing substantial is pending, the alternative to a small release is **no
release** — and then a fix sits on disk instead of on the user's machine. That is the
worse trade.

Therefore, from v1.19.45 on:

- **Small changes and hotfixes ship on their own.** No travel companion required, no
  sprint to be cut, no plan to be written first.
- **Bundle only what genuinely arrives together.** Bundling stays a courtesy to the
  reader of the history, not an obligation to the author.
- **⚠️ Do not manufacture work to fill a release.** The old rule guarded against
  ceremony; the new one has to guard against the opposite — a backlog item built
  because a release felt due. Work arrives from **practice**, not from the list. The
  four most recent entries all came that way: `.bpmn` in Camunda Modeller, the update
  check behind a shared IP quota, the seventy-year axis, the overlapping labels.
- **⚠️ A visible feature gets its help line in the same commit.** Not later, not in a
  follow-up. `HelpView.swift` already carries the lesson from UX-39 — five shipped
  shortcuts were missing from the help, and *"a help that says something other than
  the app is worse than none: that one gets believed"*. The answer then was right and
  **only half applied**: the shortcut table is generated from `Shortcuts` in the core
  and verified by `CoreChecks`, and it has been correct ever since. The prose beside it
  stayed hand-kept and drifted the same way — by v1.19.48 it claimed a dropped folder
  becomes the *root folder*, the exact opposite of what the code's own `⚠️` says, and
  it did not mention the Office filter, the file-type tab or "Arbeit fortsetzen" at
  all. Prose cannot be generated, so this rule is the guard, and it is weaker than a
  check on purpose — a check that cannot exist is no argument against the weaker one.
- **Nothing else is relaxed.** `swift build` and `swift run CoreChecks` stay green,
  `decision-check` still runs before a decision that would earn a `⚠️`, and
  `ux-review` still runs before anything visible ships. **Those obligations were never
  about size** — the label overlap was a two-line change and shipped broken because
  the review had been skipped.

If a substantial item ever returns, this section goes back to what it said. The old
text is one commit away.

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
