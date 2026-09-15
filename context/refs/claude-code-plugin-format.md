# Claude Code plugin format (verified 2026-09-15 via claude-code-guide)

## .claude-plugin/plugin.json
Required: `name` (kebab-case). Optional: `description`, `version` (explicit pin; if omitted, git SHA is the version), `author {name,email,url}`, `displayName`, `homepage`, `repository`, `license`, `keywords`.

## .claude-plugin/marketplace.json (repo doubles as marketplace)
```json
{ "name": "<marketplace-name>", "owner": {"name": "..."},
  "plugins": [ { "name": "<plugin-name>", "source": "./", "description": "...", "version": "1.0.0" } ] }
```
`source` is a path relative to the marketplace dir.

## Commands: commands/<name>.md
Frontmatter: `description`, `argument-hint`, `allowed-tools` (comma list), `disable-model-invocation`. Body receives user text as `$ARGUMENTS` (plain substitution). Invoked as `/<plugin-name>:<command>` (also bare `/<command>` if unambiguous).

## Skills: skills/<name>/SKILL.md
Frontmatter: `name`, `description` (auto-trigger criteria), `allowed-tools`, `user-invocable`, `disable-model-invocation`.

## Bundled files
`${CLAUDE_PLUGIN_ROOT}` = absolute plugin dir at runtime; usable in plugin.json and in bash calls written in command/skill bodies.

## Install / update / test
- Fresh machine: `/plugin marketplace add <owner>/<repo>` then `/plugin install <plugin>@<marketplace>`.
- Update: bump `version` in plugin.json, push; users get update notice, `/reload-plugins`.
- Version visible in `/plugin list`.
- Local testing: `/plugin marketplace add ./path` (relative to cwd; plugin `source` relative to marketplace dir; auto-update off for local).

## Image pin decided
`ghcr.io/php-cs-fixer/php-cs-fixer:3.95.25-php8.5` (latest release v3.95.25; tags exist for php8.0–8.5). Already pulled on this host.
GitHub owner: alecszaharia. Host uid:gid 1000:1000.
