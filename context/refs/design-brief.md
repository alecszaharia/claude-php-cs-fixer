# Design brief: claude-php-cs-fixer (approved 2026-09-15)

## Purpose
php-cs-fixer as a Claude Code tool. Installable on other PCs (Linux, macOS) from the user's own GitHub repo which doubles as a plugin marketplace. Runs php-cs-fixer inside a container so no host PHP/composer is required (this host has none).

## Decisions (user-approved)
- Delivery: Claude Code plugin (manifest + marketplace-in-repo + slash command + skill). Install on new PC: add marketplace by owner/repo, install plugin.
- Trigger: on demand only. No hooks. No auto-fix.
- Runtime: one pinned official php-cs-fixer container image (newest PHP tag). Bump tag = plugin version bump.
- Config resolution: project config wins (php-cs-fixer precedence .php-cs-fixer.php then .php-cs-fixer.dist.php); else bundled default = @Symfony, non-risky, short array syntax. Output states which config applied.
- Custom fixers: project root is mounted at the identical absolute path inside the container so config using __DIR__ / vendor/autoload.php works when vendor exists. Missing vendor -> surface php-cs-fixer's error verbatim.
- File ownership: on Linux the container runs as invoker's uid:gid; macOS unchanged behaviour.
- Cache: project-local .php-cs-fixer.cache, reused between runs.
- Operations: fix, check (dry-run + diff, non-zero exit on violations), pass-through of arbitrary php-cs-fixer flags.
- Default scope with no path: git-modified + staged + untracked .php files. Explicit files/dirs honored. No git and no path -> error asking for path.
- Preflight: docker CLI missing / daemon unreachable / image pull failure / outside any project -> distinct one-line messages, non-zero exit, no partial run. Exit code distinguishes violations from tool error.
- Output: agent-friendly summary (counts, changed file list, diff for check).
- Plugin: runner bundled inside plugin (no run-time fetching); skill with explicit trigger + do-not list; version declared; self-verification fixture + script in repo.
- OS: Linux + macOS. Windows out of scope.

## Domains (Approach A)
1. runner — containerized execution contract, usable from plain shell. R1 containerized execution, R2 mount fidelity, R3 file ownership, R4 config resolution, R5 custom fixers, R6 operations, R7 default scope, R8 preflight errors, R9 agent-friendly output.
   Out of scope: Windows, hooks, PHP version detection, custom Dockerfile, CI wiring, scaffolding configs, running project-local vendor/bin/php-cs-fixer.
2. plugin — packaging + Claude integration. R1 installable from repo, R2 slash command mapping 1:1 to runner, R3 skill guidance (human-review flagged), R4 runner bundled not fetched, R5 prerequisite reporting, R6 versioning, R7 self-verification fixture.
   Out of scope: hooks, MCP, Windows, third-party marketplaces, auto-update, editor integrations.
Dependency: runner -> plugin. plugin depends on runner R6/R7/R8/R9.

## Environment facts
- Host: Arch Linux, Docker 29.7.2, Compose 5.5.1, no php/composer/php-cs-fixer.
- User's existing config example (brizy-texts-extractor): @Symfony, array_syntax short, no_unneeded_curly_braces false, phpdoc_summary false, declare_strict_types true (risky; NOT in bundled default).
- User already uses official-marketplace plugins (php-lsp), so marketplace install flow is proven on this setup.
