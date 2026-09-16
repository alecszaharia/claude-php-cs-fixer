# Changelog

## VERSION-IMAGE mapping

One line per released plugin version, recording the **default** image: the pinned php-cs-fixer release plus the default PHP version. Changing either requires a new plugin version; `tests/verify.sh` asserts that the line for the version in `.claude-plugin/plugin.json` matches the image a run with no project PHP signal resolves to. The PHP suffix a given run actually uses is resolved from the project (see README, "PHP version") and is deliberately not pinned per release.

- 1.1.0: ghcr.io/php-cs-fixer/php-cs-fixer:3.95.25-php8.5
- 1.0.0: ghcr.io/php-cs-fixer/php-cs-fixer:3.95.25-php8.5

## Unreleased

- The PHP version php-cs-fixer runs on is now taken from the project instead of being fixed at the runner's pinned default. Order: `--php X.Y`, `PHPCSFIXER_PHP`, `composer.json` `config.platform.php`, the floor of `composer.json` `require.php`, `.php-version`, then the pinned default. The php-cs-fixer release stays pinned — only the PHP part of the image tag moves, so every selectable version runs the identical fixer. Published versions: 7.4, 8.0–8.5.
- Every run now starts with a `php: <version> (<source>)` line naming the version that applied and where it came from. Callers that parsed the summary positionally must account for it; label-based parsing is unaffected.
- A detected version outside the published range is clamped into it and the `php:` line states the clamp. An explicitly requested version outside it is a tool error listing what exists — an explicit request is honoured exactly or refused, never silently substituted.
- The container now runs with `--network=none`. Formatting never needs the network, and a project `.php-cs-fixer.php` is arbitrary PHP that php-cs-fixer executes against a read-write mount.
- Unmerged (conflicted) files are excluded from the default git working-set scope; previously their conflict markers failed to lint and turned the whole run into a tool error.
- Listed paths no longer collapse when a file name contains a `N) ` sequence.
- `tests/verify.sh` now exercises the docker-CLI-absent branch specifically (previously masked by the earlier git lookup) and asserts the git-absent cause separately.

## 1.1.0

- `check` now reports the changed-file list only; the unified diff is opt-in via `-- --diff`.
- A successful `fix` through the slash command prints nothing: the command discards the runner's stdout so a rewrite costs no agent context. Failures still arrive on stderr. Run `bin/php-cs-fixer-docker fix` directly to get the summary in a shell.
- Behaviour change: callers that parsed `--- diff ---` out of a plain `check` must now pass `-- --diff`.

## 1.0.0

- Initial release: `check` and `fix` operations, git working-set default scope, project config precedence over bundled `@Symfony` default, Linux uid/gid mapping, agent-friendly summary output.
