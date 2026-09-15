# Changelog

## VERSION-IMAGE mapping

One line per released plugin version. Bumping the pinned image tag requires a new plugin version; `tests/verify.sh` asserts that the tag in `bin/php-cs-fixer-docker` matches the line for the version in `.claude-plugin/plugin.json`.

- 1.0.0: ghcr.io/php-cs-fixer/php-cs-fixer:3.95.25-php8.5

## 1.0.0

- Initial release: `check` and `fix` operations, git working-set default scope, project config precedence over bundled `@Symfony` default, Linux uid/gid mapping, agent-friendly summary output.
