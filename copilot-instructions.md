# copilot-instructions.md

*Stand: v1.19.5 · 2026-08-06*

Architecture, coding, and collaboration guidelines. All rules are binding for every code change.
Existing patterns take precedence in conflicts.

**Goal:** Modular, maintainable code — small focused modules, predictable structure, admin-friendly configuration.

---

## Core Principles

These four principles are non-negotiable. All other rules are their application.

### 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

- State assumptions explicitly before implementing. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.
- Design module interfaces and agree on signatures **before** writing implementations.

### 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

**Scope:** Implement only explicitly requested features; do not add functionality unless explicitly specified in the requirements.
- No abstractions for single-use code. No unnecessary layers.
- No "flexibility" or "configurability" that wasn't explicitly requested.

**Structure:** Keep code as small as it can be while remaining clear.
- No pass-through code: wrappers must add value (validation, transformation, orchestration).
- No error handling for scenarios that cannot occur.
- If you write 200 lines and it could be 50, rewrite it.

*Ask: "Would a senior engineer call this overcomplicated?" If yes, simplify.*

> **Example — anti-pattern:** Creating a `BaseHandler → ConcreteHandler` class hierarchy for a single script
> that runs once. Just write the function.

### 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it — don't delete it.
- Breaking changes only when explicitly required; document them clearly.
- Preserve backward compatibility unless the task requires otherwise.
- Remove imports/variables/functions that **your** changes made unused. Leave pre-existing orphans alone.

*The test: every changed line should trace directly to the request.*

### 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals before starting:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan first:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
```

When a change would increase complexity beyond the module's current level, propose refactoring first — don't silently extend an overloaded module.

---

## Code & Architecture

### Module Structure

- **Focused modules:** one semantic concern per module — orchestration, parsing, IO, validation, domain logic.
- **Entry points orchestrate only.** No core business logic in `main()` or CLI handlers.
- **Two modules always read together → consider merging.** Don't over-split.
- **Fast orientation:** it must be immediately clear where config, orchestration, logic, IO, and output live.

> **Example — good split:** `invoice_parser.py` (parsing), `invoice_store.py` (IO), `invoice_cli.py` (orchestration).
> **Bad:** everything in `invoice_utils.py`.

### Naming

- Avoid `utils.py`, `helpers.py`, `misc.py` and vague suffixes like `_manager`, `_service`, `_handler` unless genuinely specific.
- **Public API:** no leading underscore = public; document and maintain backward compatibility.
- **Private internals:** `_name` — may change without notice.
- Configuration terms: business names (`target`, `threshold`, `strategy`) over technical jargon.
- Deprecation: `warnings.warn()` + docstring notice before removing anything public.

> **Bad:** `utils.process(data)` — **Good:** `invoice_parser.extract_line_items(raw_text)`

### Function & Interface Design

- **Top-down flow:** `main()` reads like an execution plan; use numbered comments when order matters.
- **No mixed concerns** in one function — separate parsing, transformation, reporting, file handling.
- **No pointless helpers:** don't extract a function that only wraps one call and hurts readability.
- **Clear signatures:** explicit parameters; avoid `**kwargs` as a catch-all.
- **Type hints** on all new or modified functions.
- **Explicit structures** over bare dicts when structure is known — use `dataclasses` or Pydantic.
- **Clean imports:** expose clean interfaces; avoid deep submodule imports (`from pkg.sub.sub import X`).
- **Dependency direction:** dependencies flow one way. No circular imports. Orchestration imports domain; domain does not import orchestration.

### Dependencies

- Prefer stdlib. No new external dependency without clear, documented justification.
- Review, pin versions in production. Don't add a 5 MB library to solve a 5-line problem.

---

## Configuration

- **No hardcoding:** paths, thresholds, flags, env-specific values → `config/`.
- **One obvious place:** each config change lives in exactly one location.
- **Central loading:** no scattered config reads. Never commit secrets.
- **No duplication:** compute derived values in code, not by copy-pasting config values.
- **Admin clarity:** readable terms, consistent schema, one working default example.
- **Secrets:** load from env vars or a secrets manager excluded from version control.
- **Doc sync:** update config examples when format changes.

> **Example of a derived value:** if `config.base_path` exists, compute `config.archive_path = base_path / "archive"` in code — don't require admins to set both.

---

## Documentation & Comments

- **File header:** every Python file starts with a one-sentence concrete purpose statement — not the filename restated.
- **Docstrings:** all public functions document purpose, parameters, return values, and side effects.
- **Orchestration functions** document the workflow they coordinate.
- **Intentional comments only:** explain *why*, not *what*. Don't comment obvious code.
- **Docs location:** `docs/`; link from README with clickable Markdown links.
- **Encoding:** UTF-8 everywhere.
- **Abbreviations:** Spell out on first use with the abbreviation in parentheses; short form allowed thereafter. No implicit domain knowledge.
- **Code formatting in docs:** Use backtick formatting for filenames, paths, commands, and config keys in all documentation.
- **File naming:** No version suffixes (`_final`, `_v2`, `_neu`). Version history belongs in VCS. Use `YYYY-MM-DD` (ISO 8601) for date-based naming.
- **Document stamp:** every Markdown document carries version and date directly below its top-level heading — `*Stand: v1.19.4 · 2026-08-06*`. Without it, a reader cannot tell which state of the software a document describes.
- **Stamp only what changed:** the release stamps exactly those documents it modified. Stamping all of them would claim a currency that does not exist — a document untouched for ten releases would then assert it is up to date.
- **Never maintain stamps by hand:** the release tooling writes them. A hand-kept stamp goes stale silently, and a stale stamp is worse than none, because readers believe it.
- **Anchor the stamp by position, not by pattern:** it lives directly below the first heading. A pattern search hits the *example* inside any document that documents the stamp itself.
- **Documentation changes go through the release:** a stamp needs a version to refer to, so even doc-only changes bump the patch number.
- **Term consistency:** One concept — one term throughout all docs. Synonyms confuse. Create a shared glossary when multiple documents share vocabulary.

> **Bad comment:** `# increment counter` — **Good:** `# retry limit reached; route to dead-letter queue`
>
> **Bad docstring:** `"""InvoiceParser class."""` — **Good:** `"""Extracts structured line items from raw PDF invoice text."""`
>
> **Bad abbreviation:** `SVN speichert jede Version.` — **Good:** `Apache Subversion (SVN) speichert jede Version. SVN ist damit …`
>
> **Bad filename:** `konzept_final_v3_neu.md` — **Good:** `2026-06-07_kgv_archivierungskonzept.md`
>
> **Bad stamp:** a heading that reads `# Spezifikation (Stand v1.19.0)` while the software is at `v1.19.3` — hand-kept and three releases behind. **Good:** `*Stand: v1.19.4 · 2026-08-06*` written by the release tooling, only for documents that release actually changed.

---

## Error Handling & Validation

### Error Handling

- **Meaningful exceptions:** include context — what was attempted, params, state. Never `raise Exception("error")`.
- **Use built-in types:** `ValueError`, `TypeError`, `FileNotFoundError`, etc. Custom exceptions only for domain-specific needs.
- **Preserve chain:** `raise NewError(f"context: {detail}") from original_error`. Never swallow tracebacks.
- **No silent failures:** no bare `except:` or `except Exception: pass`.
- **Catch selectively:** only when you can recover or meaningfully add context.
- **User-facing messages:** actionable, no jargon. Technical detail stays in logs.

> **Bad:** `except Exception: pass`
> **Good:** `except FileNotFoundError as e: raise ConfigError(f"Config missing at {path}") from e`

### Validation

- **Fail fast:** validate at entry points (CLI args, config load, external API responses). Don't pass invalid data inward.
- **Schema validation:** validate YAML/JSON at load time with an explicit schema.
- **Type safety:** `dataclasses` or Pydantic for known structures. Don't thread bare dicts through the system.
- **Field validation at construction time**, not at usage time.
- **Immutability:** frozen dataclasses or tuples for config and shared state.
- **Explicit critical settings:** require explicit values; safe defaults only where truly safe.
- **Clear error messages:** state what's wrong, what was expected, and where (file, key, line number).

> **Bad default:** `timeout = config.get("timeout", None)` silently disabling timeouts in prod.
> **Good:** raise `ConfigError("timeout is required")` if missing.

### Security

- **Sanitize all external inputs** before use.
- **No secrets in code or logs.** Redact/mask sensitive data before logging.
- **Secure file ops:** validate and canonicalize paths; prevent directory traversal. Prefer absolute paths.
- **Least privilege:** request minimal permissions; avoid admin/root.
- **Secure defaults:** deny-by-default for security-relevant features.

---

## Logging

- **`logging` module** — never `print()` for operational output.
- **Consistent format:** timestamp, level, module, message.
- **Log with context:** exceptions include params and state at the time of failure.
- **Terminal output** is separate and intentional: concise operator feedback for start-up, key events, and completion.
- **Both matter:** terminal output does not replace log files. Log what matters for troubleshooting.

---

## Testing

- **New logic requires tests.** Pure functions and small modules make this straightforward.
- **Tests cover:** config loading, parsing, core domain logic, error paths, edge cases at boundaries.
- **Goal-driven:** the test defines "done" — write it before or alongside the implementation.
- **Structural improvement over extension:** if adding tests to a module feels painful, the module needs splitting first.
- **Smoke tests for integration environments** (e.g., n8n Code Nodes, external services): minimal tests verifying import availability and critical paths — not full unit suites.
- **Tests document expected behavior.** A well-named test is worth more than a comment.

> **Example naming:** `test_extract_line_items_raises_on_empty_pdf` beats `test_case_3`.

---

## Commit Discipline

- **Atomic commits:** one logical change per commit. Don't bundle a bugfix with a refactor.
- **Meaningful messages:** `fix: handle empty invoice gracefully` beats `fix stuff`. Use conventional commits when the project does.
- **Never commit:** secrets, hardcoded credentials, debug `print()` statements, commented-out code blocks left "just in case".

---

## Performance Awareness

- Don't optimize prematurely — but don't ignore obvious issues.
- Flag O(n²) operations on potentially large inputs. Flag unbounded memory growth.
- Profile before assuming a bottleneck. Measure, then fix.

---

## Technical Debt

- When you spot debt unrelated to your task: **mention it, don't fix it silently**.
- When your change would make existing debt significantly worse: raise it before proceeding.
- Refactor proposals belong in a ticket or comment, not in a surprise commit.

---

## Communication & Language

| Context | Language |
|---|---|
| Customer communication | German |
| Docs, guides, READMEs | German |
| Code review / chat | German |
| Inline comments, docstrings | German |
| Code identifiers, commit messages | English |
