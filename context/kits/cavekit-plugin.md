---
created: "2026-09-15T13:19:29Z"
last_edited: "2026-09-15T13:45:00Z"
complexity: medium
---

# Cavekit: Plugin

## Scope
Packaging and Claude Code integration. Covers distributing the tool as a Claude Code plugin from the user's own GitHub repository, which doubles as its own plugin marketplace: installability on a fresh Linux or macOS machine, the on-demand slash command that exposes the runner, the skill that tells Claude when and how to use it, bundling the runner so nothing is fetched at run time, reporting of missing prerequisites, version declaration and its coupling to the pinned image tag, and the self-verification fixture proving an installed plugin works.

Execution behaviour itself is defined in cavekit-runner.md and is not restated here.

## Requirements

### R1: Installable from repo
**Description:** The repository is itself a Claude Code plugin marketplace. A user on a fresh machine adds the marketplace by `owner/repo` and installs the plugin from it; no manual copying, no build step, no additional tooling.

**Acceptance Criteria:**
- [ ] Adding the marketplace by `owner/repo` succeeds against a clean Claude Code installation and lists this plugin.
- [ ] Installing the plugin from that marketplace succeeds on Linux and on macOS with no host PHP, composer, or php-cs-fixer present.
- [ ] After install and with no further steps, the plugin's slash command is available in a new Claude Code session.
- [ ] Install requires no commands beyond adding the marketplace and installing the plugin.

**Dependencies:** R4, R6

### R2: Slash command mapping 1:1 to runner
**Description:** A single on-demand slash command exposes the runner. Its operations, arguments, and flag pass-through correspond one-to-one to the runner's contract — the command adds no operations of its own and removes none. There is no automatic or hook-driven invocation.

**Acceptance Criteria:**
- [ ] The command supports `fix` and `check` and exactly these two operations (runner R6).
- [ ] Path arguments given to the command reach the runner unchanged; omitting the path yields the runner's default git working-set scope (runner R7).
- [ ] Arbitrary extra php-cs-fixer flags given to the command reach php-cs-fixer unchanged (runner R6).
- [ ] The command's outcome (summary, diff, changed-file list, exit status) is the runner's, not a reformatted substitute (runner R9).
- [ ] The plugin registers no hooks and no event-driven triggers; the command only runs when explicitly invoked.

**Dependencies:** runner R6, runner R7, runner R9

### R3: Skill guidance
**Description:** A skill tells Claude when to reach for this tool and, explicitly, what not to do with it — including not auto-fixing, not editing files as a substitute for it, and not installing PHP tooling on the host.

**Acceptance Criteria:**
- [ ] The skill states explicit trigger conditions for invoking the tool (human review).
- [ ] The skill contains an explicit do-not list covering at minimum: do not run it unprompted/automatically, do not hand-edit style issues instead of running it, do not install PHP, composer, or php-cs-fixer on the host (human review).
- [ ] The skill directs Claude to `check` before `fix` when the user has not asked for rewrites (human review).
- [ ] The skill is discoverable by Claude after plugin install without the user naming it (human review).

**Dependencies:** R2

### R4: Runner bundled not fetched
**Description:** The runner ships inside the plugin. Nothing is downloaded, cloned, or fetched at run time; the only network access a run may need is the container image pull performed by Docker.

**Acceptance Criteria:**
- [ ] The installed plugin contains the complete runner; no run-time download of runner content occurs.
- [ ] With the container image already present locally and host networking disabled, a `check` run still completes.
- [ ] The runner contains no instruction that fetches anything over the network other than the container image pull (inspection criterion; the behavioural guarantee is the previous criterion).
- [ ] The runner version that executes is the one shipped with the installed plugin version, not a separately resolved copy.

**Dependencies:** runner R1

### R5: Prerequisite reporting
**Description:** When a prerequisite is missing, the user sees the runner's distinct one-line cause message rather than a generic plugin failure, and the run stops without partial effect.

**Acceptance Criteria:**
- [ ] With the Docker CLI absent, the command's output contains the runner's specific message for that cause (runner R8).
- [ ] With the Docker daemon unreachable, the command's output contains the runner's specific message for that cause and not the CLI-absent message.
- [ ] On image pull failure and on "no scope" (outside any git repository with no path argument), the corresponding distinct runner messages are surfaced.
- [ ] In each case the command reports failure to the user and no project file is created or modified.

**Dependencies:** runner R8

### R6: Versioning
**Description:** The plugin declares its version. The pinned container image tag is part of the plugin's released contract: bumping the image tag requires a plugin version bump.

**Acceptance Criteria:**
- [ ] The installed plugin reports a version, and it is visible to the user after install.
- [ ] Each released version corresponds to exactly one pinned image tag (runner R1).
- [ ] A change to the pinned image tag is accompanied by a version increase in the same change; a repo-local assertion (part of the R7 verification script, not a CI pipeline) fails if the tag recorded for the current version differs from the tag in use.
- [ ] The repository documents the release step of bumping version together with the image tag.

**Dependencies:** runner R1

### R7: Self-verification fixture
**Description:** The repository contains a small deliberately-misformatted PHP fixture and an automated script that exercises the installed plugin end to end and reports pass/fail without interactive judgement.

**Acceptance Criteria:**
- [ ] The repository contains a PHP fixture that violates the bundled default configuration (runner R4).
- [ ] The verification script passes the fixture path explicitly (never relying on runner R7 default scope) and runs `check` on it, asserting non-zero exit plus a diff mentioning the fixture file (runner R6).
- [ ] The verification script runs `fix` on a disposable copy of the fixture and asserts the copy becomes clean under a subsequent `check`.
- [ ] The script exits zero on success and non-zero on any failed assertion, with no interactive prompts.
- [ ] The script leaves the repository working tree unchanged after a successful run.

**Dependencies:** R1, R2, runner R4, runner R6

## Out of Scope
- Claude Code hooks.
- MCP servers.
- Windows support.
- Publishing to or depending on third-party marketplaces.
- Auto-update of the plugin or the pinned image.
- Editor / IDE integrations.

## Cross-References
- See also: `cavekit-runner.md` — this plugin consumes the runner's interface and depends on runner R6 (operations and flag pass-through), R7 (default scope), R8 (preflight error messages), and R9 (agent-friendly output). Runner R1 (pinned image) constrains plugin R6 versioning; runner R4 (bundled default config) defines what the R7 fixture must violate.
- See also: `cavekit-overview.md`.

## Changelog
- 2026-09-15: Review fixes — R4 network criterion made inspectional; R6 tag/version assertion scoped to repo-local script; R7 script passes fixture path explicitly.
- 2026-09-15: Initial draft from `context/refs/design-brief.md` (approved 2026-09-15).
