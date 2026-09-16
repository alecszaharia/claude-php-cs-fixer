---
created: "2026-09-15T13:19:29Z"
last_edited: "2026-09-15T13:45:00Z"
---

# Cavekit Overview

## Project
**claude-php-cs-fixer** — php-cs-fixer as a Claude Code tool. php-cs-fixer runs inside a pinned official container image, so no host PHP, composer, or php-cs-fixer is required. It is delivered as a Claude Code plugin from the user's own GitHub repository, which doubles as its own plugin marketplace, and is installable on Linux and macOS. Invocation is on demand only: `fix`, `check`, and pass-through of arbitrary php-cs-fixer flags.

Source of truth: `context/refs/design-brief.md` (approved 2026-09-15), Approach A decomposition.

## Domain Index

| Domain | Cavekit File | Requirements | Status | Description |
|---|---|---|---|---|
| Runner | `cavekit-runner.md` | 10 (R1–R10), 53 criteria | APPROVED | Containerized php-cs-fixer execution contract, usable from a plain shell: release pinning, mount fidelity, file ownership, config resolution, custom fixers, operations, default scope, preflight errors, agent-friendly output, PHP version selection. |
| Plugin | `cavekit-plugin.md` | 7 (R1–R7), 33 criteria | APPROVED | Packaging and Claude Code integration: marketplace-in-repo install, slash command, skill guidance, bundled runner, prerequisite reporting, versioning, self-verification fixture. |

**Coverage:** 2 domains, 17 requirements, 86 acceptance criteria. 4 criteria are flagged `(human review)` — all in plugin R3 (skill guidance quality).

## Cross-Reference Map

| Domain A | Interacts With | Interaction Type |
|---|---|---|
| Plugin | Runner R6 (Operations) | Consumes — slash command maps 1:1 onto `fix`, `check`, and flag pass-through |
| Plugin | Runner R7 (Default scope) | Consumes — omitted path yields the runner's git working-set scope |
| Plugin | Runner R8 (Preflight errors) | Consumes — surfaces the runner's distinct one-line cause messages verbatim |
| Plugin | Runner R9 (Agent-friendly output) | Consumes — presents the runner's summary and diff without substitution |
| Plugin R4 (Runner bundled) | Runner R1 (Containerized execution) | Packages — the runner ships inside the plugin; no run-time fetching |
| Plugin R6 (Versioning) | Runner R1 (Pinned release) | Constrained by — a php-cs-fixer release or default-PHP bump requires a plugin version bump |
| Plugin R2 (Slash command) | Runner R10 (PHP version selection) | Consumes — the command forwards the caller's PHP override and presents the resolved `php:` line without substitution |
| Plugin R7 (Self-verification) | Runner R4 (Config resolution) | Exercises — fixture must violate the bundled default configuration |
| Runner | Plugin | Provides — the runner is standalone and has no knowledge of the plugin |

## Dependency Graph

```
runner  ──provides interface──▶  plugin

runner (internal)
  R1 containerized execution
   ├─▶ R2 mount fidelity
   │    ├─▶ R3 file ownership
   │    ├─▶ R4 config resolution ──▶ R5 custom fixers
   │    └─▶ R6 operations ──▶ R7 default scope
   ├─▶ R8 preflight errors  (also from R7)
   ├─▶ R9 agent-friendly output  (from R4, R6, R7, R8, R10)
   └─▶ R10 PHP version selection  (from R2; errors via R8, reported via R9)

plugin (internal + external)
  R4 runner bundled  ◀── runner R1
  R6 versioning      ◀── runner R1
  R1 installable     ◀── plugin R4, plugin R6
  R2 slash command   ◀── runner R6, R7, R9
  R3 skill guidance  ◀── plugin R2
  R5 prerequisites   ◀── runner R8
  R7 self-verify     ◀── plugin R1, plugin R2, runner R4, runner R6
```

No circular dependencies: the runner never depends on the plugin.
