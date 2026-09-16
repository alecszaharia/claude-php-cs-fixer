---
created: "2026-09-15T13:19:29Z"
last_edited: "2026-09-15T13:45:00Z"
complexity: medium
---

# Cavekit: Runner

## Scope
The containerized php-cs-fixer execution contract. Covers how php-cs-fixer is invoked against a project without any host PHP, composer, or php-cs-fixer installation: container runtime and image pinning, project mounting, file ownership of written files, configuration resolution, custom fixer support, the supported operations and flag pass-through, default file scope selection, preflight failure reporting, and the summary output produced for an agent reader.

The runner is usable standalone from a plain shell — no Claude Code, no plugin required. Packaging and Claude Code integration live in cavekit-plugin.md.

## Requirements

### R1: Containerized execution
**Description:** php-cs-fixer runs inside the official php-cs-fixer container image. The php-cs-fixer release is pinned, not floating; the PHP component of the tag is resolved per run by R10, within the set of PHP versions the pinned release publishes. No host PHP, composer, or php-cs-fixer binary is required or used.

**Acceptance Criteria:**
- [ ] On a host with no `php`, `composer`, or `php-cs-fixer` on `PATH`, a fix run and a check run both complete and produce their normal results.
- [ ] The container image reference used at runtime includes an explicit php-cs-fixer version tag; it is never `latest` and never unpinned.
- [ ] Two consecutive runs on the same project, with no intervening change to the runner, resolve to the identical image reference.
- [ ] The image reference appears in exactly one place in the runner, so a release bump is a single-point change.
- [ ] Changing the resolved PHP version changes only the PHP component of the tag; the php-cs-fixer release is identical across every PHP version the runner can select.

**Dependencies:** none (root requirement of this kit)

### R2: Mount fidelity
**Description:** The **project root** `P` is resolved once per run by a single rule: the top-level directory of the git repository containing the invoking working directory; if the working directory is not inside a git repository, the working directory itself. R4 (config lookup), R6 (cache location), R7 (scope) and R8 (preflight) all refer to this same `P`. `P` is made available inside the container at the identical absolute path it has on the host, so that path-dependent configuration and tooling behave the same inside and outside the container.

**Acceptance Criteria:**
- [ ] Inside a git repository, `P` equals the repository top-level directory even when invoked from a subdirectory; outside any git repository, `P` equals the invoking working directory.
- [ ] For a project at host absolute path `P`, php-cs-fixer executes with `P` as its working directory inside the container and the project contents are visible there.
- [ ] A project configuration using `__DIR__` resolves to a path under `P` (verifiable by a config that echoes or uses `__DIR__` to locate a file that exists).
- [ ] Paths reported in runner output (changed files, diffs, errors) are valid on the host, i.e. they resolve relative to `P` and not to a container-internal alias.
- [ ] Running the same project from two different host working directories inside `P` yields the same resolved project root.

**Dependencies:** R1

### R3: File ownership
**Description:** Files written or rewritten by a run remain owned by the invoking user. On Linux the container process runs as the invoker's uid:gid. On macOS the default Docker Desktop behaviour is left unchanged.

**Acceptance Criteria:**
- [ ] On Linux, after a fix run that rewrites at least one file, the rewritten file's owner uid and group gid equal the invoking user's uid and gid.
- [ ] On Linux, files newly created by the run (including the cache file) are owned by the invoking user's uid and gid.
- [ ] On Linux, no file in the project is left owned by `root` as a result of a run.
- [ ] On macOS, the runner applies no uid/gid override and a fix run still rewrites files successfully.

**Dependencies:** R1, R2

### R4: Config resolution
**Description:** A project-supplied configuration always wins, following php-cs-fixer's own precedence (`.php-cs-fixer.php`, then `.php-cs-fixer.dist.php`). When neither exists, a default configuration bundled with the runner is used: `@Symfony` ruleset, non-risky rules only, short array syntax. Every run states which configuration applied.

**Acceptance Criteria:**
- [ ] With `.php-cs-fixer.php` present at `P`, that file is the configuration used, even if `.php-cs-fixer.dist.php` also exists.
- [ ] With only `.php-cs-fixer.dist.php` present at `P`, that file is the configuration used.
- [ ] With neither present, the bundled default applies and enables `@Symfony`, sets array syntax to short, and enables no risky rules (a file using long array syntax is rewritten to short; a file lacking `declare(strict_types=1)` is not given one).
- [ ] Each run's output names which configuration applied, distinguishing project configuration (with its path) from bundled default.

**Dependencies:** R1, R2

### R5: Custom fixers
**Description:** Project configurations that register custom fixers or otherwise load project code work when the project's composer dependencies are installed. When they are not installed, php-cs-fixer's own error is surfaced verbatim rather than being interpreted, rewritten, or hidden.

**Acceptance Criteria:**
- [ ] A project whose configuration requires its autoloader and registers a custom fixer runs successfully when the project's vendor directory is present, and the custom fixer's effect is observable in the result.
- [ ] With the vendor directory absent, the run fails and the output contains php-cs-fixer's error text unmodified.
- [ ] In that failure case the runner adds no substitute explanation or guessed remediation of its own in place of the tool error.
- [ ] That failure exits with the tool-error exit status, distinct from the violations-found status (see R8).

**Dependencies:** R2, R4

### R6: Operations
**Description:** The runner exposes two operations plus flag pass-through: `fix` (rewrites files) and `check` (dry-run reporting which files would change, non-zero exit when violations exist). Arbitrary additional php-cs-fixer flags supplied by the caller are passed through to php-cs-fixer. A project-local `.php-cs-fixer.cache` is written in the project and reused across runs.

**Acceptance Criteria:**
- [ ] `fix` on a project with violations rewrites the offending files and exits zero.
- [ ] `check` on a project with violations leaves every file byte-identical, names each file that would change, and exits non-zero.
- [ ] `check` on an already-clean project exits zero and reports no violations.
- [ ] A caller-supplied php-cs-fixer flag (e.g. `--rules`, `--verbose`, `--allow-risky=yes`) reaches php-cs-fixer and changes behaviour accordingly.
- [ ] A run produces `.php-cs-fixer.cache` at `P`; a second identical run leaves that file in place and, when php-cs-fixer's verbose output is requested, php-cs-fixer itself reports using the cache file.

**Dependencies:** R1, R2, R4

### R7: Default scope
**Description:** When the caller supplies no path, the run targets the git working-set `.php` files: modified, staged, and untracked. Explicit file or directory arguments are honoured as given. With neither git nor an explicit path, the run errors and asks for a path.

**Acceptance Criteria:**
- [ ] In a git repository with no path argument, the set of files processed equals exactly the `.php` files that are modified, staged, or untracked; unchanged tracked `.php` files are not processed.
- [ ] Non-`.php` files in the git working set are excluded from the default scope.
- [ ] Explicit file and directory arguments located under `P` are processed as given, regardless of git status, including unchanged tracked files.
- [ ] An explicit path that does not exist, or that lies outside `P`, is rejected before any php-cs-fixer work with a message naming the path, non-zero exit.
- [ ] Outside any git repository and with no path argument, the run performs no php-cs-fixer work, prints a message asking for a path, and exits non-zero. This is the same condition and the same message as R8's "no scope" preflight cause, not a separate one.
- [ ] In a git repository with an empty working set and no path argument, the run exits zero and reports that there was nothing to process.

**Dependencies:** R2, R6

### R8: Preflight errors
**Description:** Environment and invocation problems are detected before any php-cs-fixer work starts. Each failure class produces its own distinct one-line message and a non-zero exit, with no partial run. Exit status distinguishes "violations found" from "tool error".

**Acceptance Criteria:**
- [ ] Docker CLI absent, Docker daemon unreachable, image pull failure, and "no scope" (outside any git repository with no path argument, per R7) each produce a distinct single-line message identifying that specific cause.
- [ ] In every preflight failure case no container is started and no project file is created or modified.
- [ ] Every preflight failure exits non-zero. The invalid or out-of-root explicit path case of R7 uses the same tool-error exit status class as preflight failures.
- [ ] The exit status for "check found violations" differs from the exit status used for any tool error (preflight failure or php-cs-fixer failure), so a caller can tell them apart from the status alone.

**Dependencies:** R1, R7

### R9: Agent-friendly output
**Description:** Every run that reaches php-cs-fixer (i.e. passes R8 preflight) emits a plain-text summary intended for an agent reader, with fixed field labels one per line: the PHP version that applied and its source (R10), the applied configuration, the number of files processed, the number of files changed (fix) or violating (check), and the list of those files one path per line. The summary is the whole default output: the diff is the single largest thing the runner can print and an agent reader pays for it on every run, so it is emitted only when the caller asks for it by passing `--diff` through to php-cs-fixer, in which case it follows the summary after a fixed delimiter line so the two parts can be split mechanically. Preflight failures emit only their R8 one-line message, no summary. The empty-scope case of R7 (nothing to process) emits the same summary shape with zero counts and no file list.

**Acceptance Criteria:**
- [ ] Every run that reaches php-cs-fixer ends with a summary whose lines carry fixed labels and state the number of files processed and the number of files changed or violating.
- [ ] The summary lists each changed (fix) or would-change (check) file by path, one per line.
- [ ] The summary names the applied configuration as required by R4, and the applied PHP version with its source as required by R10.
- [ ] Without a caller-supplied `--diff`, no diff and no delimiter line appear in the output of either operation, however many files changed.
- [ ] With a caller-supplied `--diff`, the diff of proposed changes is present, separated from the summary by a fixed delimiter line, so a reader can split the two without parsing the diff.
- [ ] A run with zero violations produces a summary explicitly reporting zero, rather than empty output.

**Dependencies:** R4, R6, R7, R8

### R10: PHP version selection
**Description:** php-cs-fixer parses with the PHP it runs on and executes the project's own `.php-cs-fixer.php` under that same PHP, so the runtime PHP version is part of the result, not an implementation detail. The version is resolved once per run from the project itself, with an explicit override available, and is always reported. Resolution order, first hit wins: an explicit caller request (flag, then environment variable); the exact platform PHP declared in `composer.json` at `P`; the lowest version admitted by the `php` constraint in `composer.json` at `P` (a declared floor is the contract the project's code must parse on); a `.php-version` file at `P`; the runner's pinned default. Only versions published for the pinned php-cs-fixer release (R1) can be selected. A *detected* version outside that set is clamped into it and the clamp is stated; an *explicitly requested* version outside it is refused rather than silently substituted.

**Acceptance Criteria:**
- [ ] With no project signal and no explicit request, the run uses the runner's pinned default PHP version.
- [ ] An explicit caller request selects that PHP version; when both the flag and the environment variable are set, the flag wins.
- [ ] With an exact platform PHP declared in `composer.json`, that version is used even when the file also declares a `php` constraint.
- [ ] With only a `php` constraint in `composer.json`, the version used is the lowest the constraint admits, taken from its major and minor components only (a patch component in the constraint never lowers the result), including across alternatives (`^7.4|^8.0` selects 7.4) and ranges (`>=8.4 <9.0` selects 8.4).
- [ ] A `php` key at any other path in `composer.json` (for example under `require-dev`) does not drive selection.
- [ ] With no usable `composer.json` signal, a `.php-version` file at `P` is used; when both exist, `composer.json` wins.
- [ ] A detected version below the oldest published PHP, or above the newest, is clamped into the published set, and the run states both what was detected and what it was clamped to.
- [ ] An explicitly requested version that is not published, or is not a version at all, produces a preflight tool error (R8 class) naming the requested value, starts no container, and is never clamped to a different version.
- [ ] Every run that reaches php-cs-fixer reports the PHP version that applied and where it came from (R9).
- [ ] A run under a resolved non-default PHP version performs the normal operations end to end, including file ownership (R3).

**Dependencies:** R1, R2, R8, R9

## Out of Scope
- Windows support.
- Claude Code hooks or any automatic/on-save triggering.
- Installing or managing PHP versions on the host; selection is limited to the PHP versions the pinned php-cs-fixer release already publishes.
- Parsing `composer.lock`, or resolving a constraint against the set of PHP releases that actually exist (the runner reads the declared floor, it does not do version-range solving).
- A custom Dockerfile or self-built image.
- CI pipeline wiring.
- Scaffolding or generating php-cs-fixer configuration files into projects.
- Running a project-local `vendor/bin/php-cs-fixer` instead of the container.

## Cross-References
- See also: `cavekit-plugin.md` — the plugin packages and distributes this runner (plugin R4) and exposes it to Claude Code. The plugin's slash command maps 1:1 onto the operations and flag pass-through of R6, relies on the default scope of R7, surfaces the preflight messages of R8, and presents the summary of R9.
- See also: `cavekit-overview.md`.

## Changelog
- 2026-09-16: R10 added — per-project PHP version selection, previously listed Out of Scope. Motive: the runtime PHP both parses the sources and executes the project's `.php-cs-fixer.php`, so a single pinned PHP made the fixer's behaviour depend on the runner's release date rather than on the project. R1 was narrowed to pin the php-cs-fixer release only, and R9 gained the `php:` line.
- 2026-09-16: R6/R9 — `check` reports the changed-file list instead of a diff; the diff became opt-in via a caller-supplied `--diff`. Motive: the diff dominated the output an agent reader pays for on every run.
- 2026-09-15: Review fixes — defined project root `P` once (R2) and referenced it from R4/R6/R7/R8; unified R7 no-git-no-path error with R8 "no scope" cause; added out-of-root path rejection; fixed R9 output shape (plain text, fixed labels, delimiter before diff); made cache criterion observable.
- 2026-09-15: Initial draft from `context/refs/design-brief.md` (approved 2026-09-15).
