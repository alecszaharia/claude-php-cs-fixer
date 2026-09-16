# Changelog

## VERSION-IMAGE mapping

One line per released plugin version. Bumping the pinned image tag requires a new plugin version; `tests/verify.sh` asserts that the tag in `bin/php-cs-fixer-docker` matches the line for the version in `.claude-plugin/plugin.json`.

- 1.1.0: ghcr.io/php-cs-fixer/php-cs-fixer:3.95.25-php8.5
- 1.0.0: ghcr.io/php-cs-fixer/php-cs-fixer:3.95.25-php8.5

## Unreleased

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
