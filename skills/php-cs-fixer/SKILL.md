---
name: php-cs-fixer
user-invocable: false
description: PHP code style checking and fixing with php-cs-fixer in Docker (PSR-12 / Symfony conventions). Use when the user asks to format, lint, or fix PHP code style, asks whether edited PHP conforms to coding standards, mentions php-cs-fixer or PSR-12, wants a style check before committing or opening a PR with PHP changes, or hits a PHP style failure in CI. Needs only Docker on the host.
---

# php-cs-fixer

The `/php-cs-fixer:php-cs-fixer` command runs php-cs-fixer inside a pinned container image.
No PHP, composer, or php-cs-fixer is needed on the host, and none should be
installed for this purpose.

## Use when

- The user asks to format, lint, clean up, or fix the style of PHP code.
- A PHP file was just edited and the user asks whether it conforms to the
  project's coding standard.
- The user is about to commit or open a pull request touching PHP files and
  asks for a style check.
- The user mentions php-cs-fixer, PSR-12, Symfony coding standards, or a PHP
  style failure in CI.

## How

1. Run `/php-cs-fixer:php-cs-fixer check [paths]` first. With no path it covers the git
   working set (modified, staged, untracked `.php` files, excluding unmerged
   ones); pass paths to widen or narrow. Report the counts and the changed-file
   list to the user.
2. Run `/php-cs-fixer:php-cs-fixer fix [paths]` only when the user asked for rewrites or
   approved the file list from step 1. A successful `fix` prints nothing; say it
   succeeded and leave inspection to `git diff`.
3. Extra php-cs-fixer flags go after `--`, for example
   `/php-cs-fixer:php-cs-fixer check src -- --verbose`. Add `-- --diff` only when
   the user asks to see the proposed changes — the diff is large and the file
   list usually answers the question.

## Do not

- Do not run it unprompted or automatically, including after your own edits,
  on save, or at the end of a task. Run it when the user asks or when a step
  above applies.
- Do not hand-edit spacing, braces, imports, blank lines, or array syntax as a
  substitute for running the tool.
- Do not install PHP, composer, or php-cs-fixer on the host. The tool runs in a
  container by design; if Docker is missing, tell the user and stop.
- Do not reformat, summarize, or reorder the runner's output. Show it as is.
- Do not pass `--allow-risky=yes` unless the user explicitly asked for risky
  fixers.
- Do not pass `--php` to work around a failure. The version is read from the
  project; overriding it hides a mismatch between the project's declared PHP and
  its code. Pass it only when the user names a version.
- Do not edit `composer.json` or `.php-version` to change which PHP the fixer
  uses. Those describe the project, not this tool.
- Do not run `fix` on files outside the user's current change without asking.

## Interpreting output

```
php: 8.2 (composer.json config.platform.php: 8.2.5)   # or: pinned default
config: project (/abs/path/.php-cs-fixer.dist.php)   # or: bundled default (@Symfony, non-risky, short arrays)
files_processed: 3
files_changed: 1
/abs/path/src/Foo.php
--- diff ---
<unified diff, only when the caller passed `-- --diff`>
```

- `php:` says which PHP php-cs-fixer ran on and where that came from. It is read
  from the project (`composer.json`, then `.php-version`), so it usually needs
  no attention; report it as given rather than acting on it.
- `config:` says which configuration applied; a project config always wins
  over the bundled default.
- `files_changed:` means "would change" for `check` and "rewritten" for `fix`.
- A successful `fix` prints no summary at all: the command discards its stdout
  so a rewrite costs no context. Exit 0 is the whole result; `git diff` shows
  what changed. Do not re-run as `check` just to produce a summary.
- Exit 0: clean (or nothing to process). Exit 1: `check` found violations.
  Exit 2: tool or preflight error; the runner prints one cause line
  (git missing, Docker CLI missing, daemon unreachable, image pull failed, no
  scope, bad path) or php-cs-fixer's own error verbatim.
