---
created: "2026-09-15T13:36:35Z"
last_edited: "2026-09-15T13:41:07Z"
---
# Implementation Tracking: runner

Build site: context/plans/build-site.md

| Task | Status | Notes |
|------|--------|-------|
| T-001 | DONE | config/default.php-cs-fixer.php: @Symfony, short arrays, risky off, Finder at getcwd(). php -l in image clean. |
| T-002 | DONE | bin/php-cs-fixer-docker skeleton: parse_args, resolve_project_root (git toplevel else PWD, pwd -P), EXIT_* constants, map_fixer_status (8→1, other→2). Verified root from root/subdir/outside repo. |
| T-004 | DONE | run_fixer(): -v P:P -w P, bundled config ro sidecar, --user uid:gid on Linux (Darwin: none). Verified ownership 1000:1000, nothing root-owned, __DIR__ resolves, image stable. |
| T-005 | DONE | resolve_config(): .php-cs-fixer.php > .dist.php (no --config passed; label only) > bundled --config. Behaviourally proven (empty-rules project config → 0 changes). Caller --rules replaces bundled --config (php-cs-fixer forbids both). |
| T-006 | DONE | resolve_scope(): explicit paths validated (exist, under P) and made absolute; default = git status -z -uall .php (mod/staged/untracked, renames dest, deletes skipped); no-git-no-path = MSG_NO_SCOPE; empty set → zero summary exit 0. |
| T-007 | DONE | preflight_docker (CLI, daemon) → scope → config → ensure_image (pull, distinct msg). 4 MSG_* constants distinct. Tree untouched on failures. Root resolution uses builtins only. |
| T-008 | DONE | fix / check(--dry-run --diff); passthrough last; tool error → raw output verbatim to stderr, exit 2; verbosity flag → raw output to stderr + summary. Custom fixer with hand-written vendor/autoload works; missing vendor → verbatim error exit 2. |
| T-009 | DONE | print_summary awk: config/files_processed/files_changed labels, abs paths, '--- diff ---' delimiter only for check with changes; empty scope reuses same function. Verified byte-identical check, single delimiter, paths openable. |
