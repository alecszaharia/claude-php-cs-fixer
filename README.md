# claude-php-cs-fixer

[php-cs-fixer](https://github.com/PHP-CS-Fixer/PHP-CS-Fixer) as a Claude Code plugin. php-cs-fixer runs inside a Docker image at a pinned php-cs-fixer release, on the PHP version your project declares, so the host needs **no PHP, no composer, no php-cs-fixer**. Works on Linux and macOS (Docker Desktop or OrbStack). Windows is out of scope.

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
/php-cs-fixer:php-cs-fixer check [--php X.Y] [paths...] [-- php-cs-fixer flags]
/php-cs-fixer:php-cs-fixer fix   [--php X.Y] [paths...] [-- php-cs-fixer flags]
```

Plugin commands are namespaced as `/<plugin>:<command>`; interactive autocomplete also offers the short form when it is unambiguous.

- `check` is a dry run: lists the files that would change, writes nothing, exits 1 when violations exist. Add `-- --diff` to see the proposed changes themselves.
- `fix` rewrites files in place. Through the slash command a successful `fix` prints nothing — that keeps it free of an agent's context; use `git diff` to inspect the result. The runner itself still prints its summary when you run it from a shell.
- With no path the scope is the git working set of the current repository: modified, staged, and untracked `.php` files. Unmerged (conflicted) files are excluded — conflict markers are not parseable PHP. Pass a directory (for example `.`) to cover everything. Explicit paths must lie under the project root (the git top-level, or the current directory outside git).
- Anything after `--` is forwarded to php-cs-fixer unchanged, for example `-- --verbose` or `-- --allow-risky=yes`.
- `--php X.Y` (or `--php=X.Y`) picks the PHP version php-cs-fixer runs on; without it the version is read from the project. It selects the container, so it belongs *before* `--`, not after. See [PHP version](#php-version).

The runner is a plain shell script and works without Claude:

```
bin/php-cs-fixer-docker check src
bin/php-cs-fixer-docker fix -- --verbose
```

## Output contract

Every run that reaches php-cs-fixer prints:

```
php: <version> (<where it came from>)
config: <which configuration applied>
files_processed: <N>
files_changed: <N>          # "would change" for check, "rewritten" for fix
<one absolute path per affected file>
--- diff ---                # only when you passed `-- --diff`, and files_changed > 0
<unified diff>
```

The changed-file list, not the diff, is the default output: a diff of every violation is by far the largest thing the runner can print, and an agent reader pays for it on every run. Ask for it with `-- --diff` when you actually want to read it.

Exit status:

| Status | Meaning |
|-------:|---------|
| 0 | clean, or nothing to process |
| 1 | `check` found violations (php-cs-fixer's own status 8 is mapped to 1) |
| 2 | tool or preflight error: git missing, Docker CLI missing, daemon unreachable, image pull failed, no scope, invalid path, or a php-cs-fixer failure whose output is shown verbatim |

Preflight failures print a single cause line and touch no file. Passing a verbosity flag (`-- --verbose`) additionally prints php-cs-fixer's raw output on stderr.

## Configuration resolution

1. `.php-cs-fixer.php` at the project root, if present.
2. Otherwise `.php-cs-fixer.dist.php` at the project root, if present.
3. Otherwise the bundled default: `@Symfony`, non-risky rules only, short array syntax (`config/default.php-cs-fixer.php`).

Project configs are loaded by php-cs-fixer itself, so `__DIR__`, `require __DIR__ . '/vendor/autoload.php'`, and custom fixers work as long as the project's `vendor/` exists. A project config is ordinary PHP and php-cs-fixer executes it, so the container runs with `--network=none`: formatting needs no network, and a config from a repository you are merely reading cannot phone home. A caller-supplied `--rules` replaces whichever configuration was resolved, and the `config:` line says so (php-cs-fixer refuses `--config` together with `--rules`).

The project root is mounted at the same absolute path inside the container and used as the working directory; `.php-cs-fixer.cache` is written there. On Linux the container runs as the invoking user, so files keep their ownership.

## PHP version

php-cs-fixer parses your sources with the PHP it runs on, and it executes your `.php-cs-fixer.php` under that same PHP. So the runtime PHP version is part of the result: a config or custom fixer that trips over a deprecation on PHP 8.5 behaves differently from one running on 8.1. The runner therefore takes the PHP version from the project, and only falls back to its own default when the project says nothing.

Resolution order, first hit wins:

| # | Source | Example | Selected |
|--:|---|---|---|
| 1 | `--php X.Y` | `--php 8.2` | 8.2 |
| 2 | `PHPCSFIXER_PHP` | `PHPCSFIXER_PHP=8.2` | 8.2 |
| 3 | `composer.json` → `config.platform.php` | `"8.3.6"` | 8.3 |
| 4 | `composer.json` → `require.php` | `"^8.1"` | 8.1 |
| 5 | `.php-version` | `8.2.10` | 8.2 |
| 6 | the pinned default | — | 8.5 |

A `require.php` constraint is read as a **floor**: the lowest version it admits (`^7.4|^8.0` → 7.4, `>=8.4 <9.0` → 8.4). The reasoning is that a project's declared minimum is the version its code must actually parse on — if a file needs syntax newer than the constraint claims, that is worth finding out. Set `config.platform.php`, or pass `--php`, when you want the exact version instead. Only `require.php` is read, never `require-dev.php`.

The php-cs-fixer release itself is pinned; only the PHP part of the image tag moves, so every selectable version runs the identical fixer. Available: **7.4, 8.0, 8.1, 8.2, 8.3, 8.4, 8.5**. A *detected* version outside that range is clamped into it and the `php:` line says so:

```
php: 7.4 (composer.json require.php: ^7.2 -> 7.2 clamped to 7.4, the nearest published tag)
```

A version you asked for *explicitly* is never substituted — `--php=9.9` is a tool error listing what exists, because quietly formatting your code with something other than what you requested is worse than failing. Each distinct PHP version is a separate image, pulled once on first use.

If a project's declared version turns out to be wrong for formatting, `--php` overrides it for that run without touching the project's files.

## Verification

```
bash tests/verify.sh
```

Runs `check` and `fix` against `tests/fixture/Sample.php` (on a disposable copy), and asserts ownership, config precedence, PHP version resolution, cache reuse, preflight messages, offline operation, and the version-to-image mapping. Exits 0 only when every assertion passes. Run it after installing on a new machine. It pulls two images: the default one and one non-default PHP, to prove a resolved version is a real image and not just a well-formed tag.

## Release procedure

The pinned php-cs-fixer release and the default PHP version are part of the released contract. Changing either without a plugin version bump is not a valid release. Which PHP a given run resolves to is a property of the project, not of the release.

1. Bump `version` in `.claude-plugin/plugin.json` **and** `.claude-plugin/marketplace.json`.
2. Bump `IMAGE_BASE` in `bin/php-cs-fixer-docker` (the only place the image lives). Adjust `PHP_SUPPORTED` and `PHP_DEFAULT` if the new release publishes a different set of PHP tags.
3. Add `- <version>: <IMAGE_BASE>-php<PHP_DEFAULT>` to the `## VERSION-IMAGE mapping` block in `CHANGELOG.md` and write the release entry.
4. Run `bash tests/verify.sh`; it fails if the mapped image for the current version differs from the image a run with no project PHP signal resolves to.
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
