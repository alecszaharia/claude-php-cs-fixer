---
created: "2026-09-15T13:19:29Z"
last_edited: "2026-09-15T13:19:29Z"
complexity:
---

# Cavekit: Runner

## Scope
The containerized php-cs-fixer execution contract. Covers how php-cs-fixer is invoked against a project without any host PHP, composer, or php-cs-fixer installation: container runtime and image pinning, project mounting, file ownership of written files, configuration resolution, custom fixer support, the supported operations and flag pass-through, default file scope selection, preflight failure reporting, and the summary output produced for an agent reader.

The runner is usable standalone from a plain shell — no Claude Code, no plugin required. Packaging and Claude Code integration live in cavekit-plugin.md.

## Requirements

### R1: Containerized execution
**Description:** php-cs-fixer runs inside a single pinned official php-cs-fixer container image (newest PHP tag available at release time). No host PHP, composer, or php-cs-fixer binary is required or used. The image tag is fixed, not floating.

**Acceptance Criteria:**
- [ ] On a host with no `php`, `composer`, or `php-cs-fixer` on `PATH`, a fix run and a check run both complete and produce their normal results.
- [ ] The container image reference used at runtime includes an explicit version tag; it is never `latest` and never unpinned.
- [ ] Two consecutive runs with no intervening change to the runner resolve to the identical image reference.
- [ ] The image reference appears in exactly one place in the runner, so a tag bump is a single-point change.

**Dependencies:** none (root requirement of this kit)

### R2: Mount fidelity
**Description:** The project root is made available inside the container at the identical absolute path it has on the host, so that path-dependent configuration and tooling behave the same inside and outside the container.

**Acceptance Criteria:**
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
- [ ] With `.php-cs-fixer.php` present in the project root, that file is the configuration used, even if `.php-cs-fixer.dist.php` also exists.
- [ ] With only `.php-cs-fixer.dist.php` present, that file is the configuration used.
- [ ] With neither present, the bundled default applies and enables `@Symfony`, sets array syntax to short, and enables no risky rules (a file using long array syntax is rewritten to short; a file lacking `declare(strict_types=1)` is not given one).
- [ ] Each run's output names which configuration applied, distinguishing project configuration (with its path) from bundled default.

**Dependencies:** R1, R2

### R5: Custom fixers
**Description:** Project configurations that register custom fixers or otherwise load project code work when the project's composer dependencies are installed. When they are not installed, php-cs-fixer's own error is surfaced verbatim rather than being interpreted, rewritten, or hidden.

**Acceptance Criteria:**
- [ ] A project whose configuration requires its autoloader and registers a custom fixer runs successfully when the project's vendor directory is present, and the custom fixer's effect is observable in the result.
- [ ] With the vendor directory absent, the run fails and the output contains php-cs-fixer's error text unmodified.
- [ ] In that failure case the runner adds no substitute explanation or guessed remediation of its own in place of the tool error.
- [ ] That failure exits with the tool-error exit status, distinct from the violations-found status (see R6).

**Dependencies:** R2, R4

### R6: Operations
**Description:** The runner exposes two operations plus flag pass-through: `fix` (rewrites files) and `check` (dry-run with diff, non-zero exit when violations exist). Arbitrary additional php-cs-fixer flags supplied by the caller are passed through to php-cs-fixer. A project-local `.php-cs-fixer.cache` is written in the project and reused across runs.

**Acceptance Criteria:**
- [ ] `fix` on a project with violations rewrites the offending files and exits zero.
- [ ] `check` on a project with violations leaves every file byte-identical, prints a diff of the proposed changes, and exits non-zero.
- [ ] `check` on an already-clean project exits zero and reports no violations.
- [ ] A caller-supplied php-cs-fixer flag (e.g. `--rules`, `--verbose`, `--allow-risky=yes`) reaches php-cs-fixer and changes behaviour accordingly.
- [ ] A run produces `.php-cs-fixer.cache` inside the project root, and a second identical run reuses it rather than recreating it from scratch.

**Dependencies:** R1, R2, R4

### R7: Default scope
**Description:** When the caller supplies no path, the run targets the git working-set `.php` files: modified, staged, and untracked. Explicit file or directory arguments are honoured as given. With neither git nor an explicit path, the run errors and asks for a path.

**Acceptance Criteria:**
- [ ] In a git repository with no path argument, the set of files processed equals exactly the `.php` files that are modified, staged, or untracked; unchanged tracked `.php` files are not processed.
- [ ] Non-`.php` files in the git working set are excluded from the default scope.
- [ ] Explicit file and directory arguments are processed as given, regardless of git status, including unchanged tracked files.
- [ ] Outside any git repository and with no path argument, the run performs no php-cs-fixer work, prints a message asking for a path, and exits non-zero.
- [ ] In a git repository with an empty working set and no path argument, the run exits zero and reports that there was nothing to process.

**Dependencies:** R2, R6

### R8: Preflight errors
**Description:** Environment problems are detected before any php-cs-fixer work starts. Each failure class produces its own distinct one-line message and a non-zero exit, with no partial run. Exit status distinguishes "violations found" from "tool error".

**Acceptance Criteria:**
- [ ] Docker CLI absent, Docker daemon unreachable, image pull failure, and invocation outside any project each produce a distinct single-line message identifying that specific cause.
- [ ] In every preflight failure case no container is started and no project file is created or modified.
- [ ] Every preflight failure exits non-zero.
- [ ] The exit status for "check found violations" differs from the exit status used for any tool error (preflight failure or php-cs-fixer failure), so a caller can tell them apart from the status alone.

**Dependencies:** R1, R7

### R9: Agent-friendly output
**Description:** Every run emits a structured, machine-readable summary intended for an agent reader: counts, the list of changed (or would-change) files, the applied configuration, and for `check` the diff.

**Acceptance Criteria:**
- [ ] Every successful run's summary states the number of files processed and the number of files changed or violating.
- [ ] The summary lists each changed (fix) or would-change (check) file by path, one per line.
- [ ] The summary names the applied configuration as required by R4.
- [ ] For `check`, the diff of proposed changes is present in the output and separable from the summary section.
- [ ] A run with zero violations produces a summary explicitly reporting zero, rather than empty output.

**Dependencies:** R4, R6, R7, R8

## Out of Scope
- Windows support.
- Claude Code hooks or any automatic/on-save triggering.
- PHP version detection or per-project PHP version selection.
- A custom Dockerfile or self-built image.
- CI pipeline wiring.
- Scaffolding or generating php-cs-fixer configuration files into projects.
- Running a project-local `vendor/bin/php-cs-fixer` instead of the container.

## Cross-References
- See also: `cavekit-plugin.md` — the plugin packages and distributes this runner (plugin R4) and exposes it to Claude Code. The plugin's slash command maps 1:1 onto the operations and flag pass-through of R6, relies on the default scope of R7, surfaces the preflight messages of R8, and presents the summary of R9.
- See also: `cavekit-overview.md`.

## Changelog
- 2026-09-15: Initial draft from `context/refs/design-brief.md` (approved 2026-09-15).
