# AGENTS.md

*Stand: v1.19.67 · 2026-08-13*

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
sprints/                  sprint plans, written before the code (see below)
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

## Acceptance: the agent reads, the owner clicks

`ux-review` has two halves, and only one of them belongs to the agent. **Reading the
interface** — HIG, wording, accessibility, evidence at `file:line` — is agent work.
**Operating it** is not, and the attempt cost more than the change it was checking:
roughly 60 % of one session went into making clicks work at all, 25 % into
screenshots, 15 % into the actual observation.

**⚠️ Do not automate clicks in SwiftUI views.** They expose no accessibility titles,
so every click becomes a screen coordinate computed from a screenshot, and every
layout change invalidates it. AppleScript has no right-click either. What a human
answers in two seconds costs the agent twenty minutes and is wrong more often.

**⚠️ Never run an acceptance against the owner's own settings.** On 2026-08-13 a
cleanup after such a run deleted two folders the owner had hidden. A check that can
damage what it checks is not a check. Launch with a scratch store instead:

```
ACTIVITIES_DEFAULTS_SUITE=ux open -n dist/activities.app   # writes to …abnahme.ux
defaults write com.mtri.activities.abnahme.ux <key> …      # set up state
defaults delete com.mtri.activities.abnahme.ux             # clean up
```

The running app shows an orange **Abnahme** marker in the status bar while it does —
a scratch store must never be a silent state (`SettingsStore.scratchVariable`).

**The runbook stays short because most of it must not be in it.** Anything a
`CoreChecks` assertion can reach belongs there, not in a list a human works through:
wording, numbers, which options are offered, what a rule does. The runbook holds only
what no assertion can see — *does it appear, does it open, does it change*. Three to
five yes/no lines per change. If the list grows past that, the answer is usually a
missing assertion, not a longer list.

Format: preparation (⚠️ quit **all** running instances first — driving the old one is
the most common false result), then numbered observations, each answerable with `ok`
or `nein: <what instead>`.

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

  **⚠️ The rule named only `HelpView.swift`, and that was too narrow.** On 2026-08-13
  the owner asked whether the documentation was current. The in-app help was — it had
  been updated in the same commit, exactly as this rule demands. `README.md` was not:
  it still promised a name filter that *"works while typing"* (Enter since PR-55),
  *"recently used folders"* (replaced by sources in PR-19) and *"139 assertions"*
  (1508). **Following the rule to the letter and still shipping wrong prose is the
  finding** — a rule that names one file gives the other files an alibi. The rule
  therefore covers **every** prose that describes behaviour: the in-app help,
  `README.md`, and the concept document.

  Except that the concept document is now **out of scope by decision, not by
  neglect**: it was 32 versions behind and called itself the *authoritative
  specification*, and its stated purpose — rebuilding the app on another platform —
  serves nobody. It carries a header saying it is a v1.19.35 snapshot and that the
  code wins. *A document that claims authority while contradicting the code does more
  damage than one that states its own limits.* `backlog.md` is the record.
- **Nothing else is relaxed.** `swift build` and `swift run CoreChecks` stay green,
  `decision-check` still runs before a decision that would earn a `⚠️`, and
  `ux-review` still runs before anything visible ships. **Those obligations were never
  about size** — the label overlap was a two-line change and shipped broken because
  the review had been skipped.

If a substantial item ever returns, this section goes back to what it said. The old
text is one commit away.

**⚠️ It returned on 2026-08-16, and this paragraph is the amendment.** The owner asked
for Finder-grade file operations — moving files and folders in from the Finder, creating
subfolders, renaming, trash, clipboard. That is an L, and it is the first work in
thirty-five releases that does not fit into a single afternoon. **Sprints are back for
work of that size, and only for that size.** Everything above still holds for everything
else: a two-line fix does not wait for a sprint, and no item gets built because a
release felt due. What changed is that there is now something to cut a sprint *from*.

## Sprints: the plan is a file, and it is a handover document

**⚠️ From Sprint 19 on, a sprint plan is written to `sprints/sprint-NN-<name>.md`
before any code exists.** Not into `backlog.md`, not into the conversation.

The reason is not tidiness. **The owner decides, per sprint, which model implements
it** — a cheaper one or a shallower thinking depth, to spend tokens where they earn
something. Planning and implementing are therefore separated by design, and they may
happen in different sessions with different models and no shared memory.

That has one consequence, and it is the whole rule: **the plan must work without the
conversation that produced it.** Anything an implementer would otherwise have to ask
is a defect in the plan. Concretely, a plan carries:

- the assignment **in the owner's own words**, quoted, not paraphrased;
- what already exists and where — file paths, not descriptions;
- the work packages with effort, and what depends on what;
- **the open decisions, marked as open**, each with the alternatives and a
  recommendation — an implementer who meets an unmarked fork will guess;
- the assertions that have to come out of it;
- the acceptance runbook;
- the rules that govern implementation, named — because the implementing model may
  never have read `AGENTS.md`.

**⚠️ Two gates apply unchanged, and the split makes them easier to skip.** The plan is
*planning* and needs no approval; **implementation still waits for an explicit go**,
and that go now includes the choice of model. And a cheaper model does not buy relief
from `swift build`, `swift run CoreChecks`, `decision-check`, `ux-review` or the help
line in the same commit. *If a model is too weak to carry those, it is too weak for
the sprint — that is the measurement, not the token count.*

**The plan stays a living document.** Decisions taken during implementation are
written back into it, so the file and the code tell the same story. When the sprint
ships, `backlog.md` gets the entry as always; the plan file remains as the record of
what was decided **before** anything was known.

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
