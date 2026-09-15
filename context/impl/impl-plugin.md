---
created: "2026-09-15T13:36:35Z"
last_edited: "2026-09-15T13:55:44Z"
---
# Implementation Tracking: plugin

Build site: context/plans/build-site.md

| Task | Status | Notes |
|------|--------|-------|
| T-003 | DONE | .claude-plugin/plugin.json + marketplace.json (name php-cs-fixer, 1.0.0, source ./), CHANGELOG VERSION-IMAGE block 1.0.0 → 3.95.25-php8.5. JSON valid, names/versions agree. |
| T-010 | DONE | commands/php-cs-fixer.md: Bash-only, runs ${CLAUDE_PLUGIN_ROOT}/bin/php-cs-fixer-docker $ARGUMENTS, verbatim output rules. Local marketplace add + install verified via CLI (version 1.0.0, hooks 0). E2E via `claude -p "/php-cs-fixer:php-cs-fixer check ..."` relayed summary+diff verbatim. Bare /php-cs-fixer not registered in print mode; namespaced form documented. macOS: inspection only. |
| T-011 | DONE | skills/php-cs-fixer/SKILL.md: trigger description, Use when / How (check before fix) / Do not (5 items) / Interpreting output. user-invocable: false to avoid name collision with the command. All 4 criteria await human review. |
| T-012 | DONE | tests/fixture/Sample.php (long arrays, spacing), tests/verify.sh core assertions; work dir is its own git repo under .verify-* (gitignored). |
| T-013 | DONE | verify.sh extended: version↔image mapping, single image literal, no-fetch grep, offline via unshare -rn, ownership, config precedence, cache reuse, 4 distinct preflight causes, bad paths, tree unchanged. 49/49 pass on this host. |
| T-014 | DONE | README: two-step install, usage, output contract + exit codes, config resolution, verification, release procedure, layout. CHANGELOG finalized in T-003. |
