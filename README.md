# claude-php-cs-fixer

[php-cs-fixer](https://github.com/PHP-CS-Fixer/PHP-CS-Fixer) as a Claude Code plugin. php-cs-fixer runs inside a pinned Docker image, so the host needs **no PHP, no composer, no php-cs-fixer**. Works on Linux and macOS (Docker Desktop or OrbStack). Windows is out of scope.

The plugin provides one slash command, `/php-cs-fixer:php-cs-fixer`, and a skill that tells Claude when to use it. It never runs automatically: no hooks, no on-save formatting.

## Requirements

- Docker (CLI + a reachable daemon). Nothing else.

## Install

Two steps inside Claude Code, on any machine:

```
/plugin marketplace add alecszaharia/claude-php-cs-fixer
/plugin install php-cs-fixer@claude-php-cs-fixer
```

No other command, build step, or host tooling is required. The pinned image is pulled on the first run.

From a terminal the same two steps are `claude plugin marketplace add alecszaharia/claude-php-cs-fixer` and `claude plugin install php-cs-fixer@claude-php-cs-fixer`. For a local checkout use `claude plugin marketplace add ./` from the repository root.

## Usage

```
/php-cs-fixer:php-cs-fixer check [paths...] [-- php-cs-fixer flags]
/php-cs-fixer:php-cs-fixer fix   [paths...] [-- php-cs-fixer flags]
```

Plugin commands are namespaced as `/<plugin>:<command>`; interactive autocomplete also offers the short form when it is unambiguous.

- `check` is a dry run: prints a diff, writes nothing, exits 1 when violations exist.
- `fix` rewrites files in place.
- With no path the scope is the git working set of the current repository: modified, staged, and untracked `.php` files. Pass a directory (for example `.`) to cover everything. Explicit paths must lie under the project root (the git top-level, or the current directory outside git).
- Anything after `--` is forwarded to php-cs-fixer unchanged, for example `-- --verbose` or `-- --allow-risky=yes`.

The runner is a plain shell script and works without Claude:

```
bin/php-cs-fixer-docker check src
bin/php-cs-fixer-docker fix -- --verbose
```

## Output contract

Every run that reaches php-cs-fixer prints:

```
config: <which configuration applied>
files_processed: <N>
files_changed: <N>          # "would change" for check, "rewritten" for fix
<one absolute path per affected file>
--- diff ---                # check only, and only when files_changed > 0
<unified diff>
```

Exit status:

| Status | Meaning |
|-------:|---------|
| 0 | clean, or nothing to process |
| 1 | `check` found violations (php-cs-fixer's own status 8 is mapped to 1) |
| 2 | tool or preflight error: Docker CLI missing, daemon unreachable, image pull failed, no scope, invalid path, or a php-cs-fixer failure whose output is shown verbatim |

Preflight failures print a single cause line and touch no file. Passing a verbosity flag (`-- --verbose`) additionally prints php-cs-fixer's raw output on stderr.

## Configuration resolution

1. `.php-cs-fixer.php` at the project root, if present.
2. Otherwise `.php-cs-fixer.dist.php` at the project root, if present.
3. Otherwise the bundled default: `@Symfony`, non-risky rules only, short array syntax (`config/default.php-cs-fixer.php`).

Project configs are loaded by php-cs-fixer itself, so `__DIR__`, `require __DIR__ . '/vendor/autoload.php'`, and custom fixers work as long as the project's `vendor/` exists. A caller-supplied `--rules` replaces the bundled default (php-cs-fixer refuses `--config` together with `--rules`).

The project root is mounted at the same absolute path inside the container and used as the working directory; `.php-cs-fixer.cache` is written there. On Linux the container runs as the invoking user, so files keep their ownership.

## Verification

```
bash tests/verify.sh
```

Runs `check` and `fix` against `tests/fixture/Sample.php` (on a disposable copy), and asserts ownership, config precedence, cache reuse, preflight messages, offline operation, and the version-to-image mapping. Exits 0 only when every assertion passes. Run it after installing on a new machine.

## Release procedure

The pinned image tag is part of the released contract. An image tag change without a plugin version bump is not a valid release.

1. Bump `version` in `.claude-plugin/plugin.json` **and** `.claude-plugin/marketplace.json`.
2. Bump the `IMAGE` constant in `bin/php-cs-fixer-docker` (the only place it lives).
3. Add `- <version>: <image>` to the `## VERSION-IMAGE mapping` block in `CHANGELOG.md` and write the release entry.
4. Run `bash tests/verify.sh`; it fails if the mapped image for the current version differs from the runner's image.
5. Tag and push. Installed plugins pick the new version up on their next update.

## Layout

```
.claude-plugin/plugin.json       plugin manifest (name, version)
.claude-plugin/marketplace.json  this repo as its own marketplace
bin/php-cs-fixer-docker          the runner
config/default.php-cs-fixer.php  bundled default configuration
commands/php-cs-fixer.md         the /php-cs-fixer:php-cs-fixer slash command
skills/php-cs-fixer/SKILL.md     when Claude should reach for it
tests/                           fixture and verify.sh
```
