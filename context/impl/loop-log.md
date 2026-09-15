# Loop Log

### Iteration 1 — 2026-09-15T13:36:35Z
- T-001: bundled default config — DONE. Files: config/default.php-cs-fixer.php. Build P, Tests P (php -l). Next: T-004
- T-002: runner skeleton — DONE. Files: bin/php-cs-fixer-docker. Build P (bash -n), Tests P (manual: root/subdir/outside, parse, status map). Next: T-004
- T-003: manifests + changelog — DONE. Files: .claude-plugin/*.json, CHANGELOG.md. Build P (JSON parse). Next: T-010/T-012 after T-009

### Iteration 2 — 2026-09-15T13:41:07Z
- T-004+T-005: docker layer + config resolution — DONE. Files: bin/php-cs-fixer-docker. Build P, Tests P (temp projects a/b/c/d). Next: T-006
- T-006+T-007: scope + preflight — DONE. Files: bin/php-cs-fixer-docker. Build P, Tests P (working-set, path rejection, 4 preflight causes, tree untouched). Next: T-008
- T-008+T-009: operations + summary — DONE. Files: bin/php-cs-fixer-docker. Build P, Tests P (byte-identical check, flags, cache, custom fixer, verbatim error). Fixes: verbose echo, --rules vs bundled --config. Next: T-010, T-012
