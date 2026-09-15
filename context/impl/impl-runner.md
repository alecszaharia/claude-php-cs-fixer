---
created: "2026-09-15T13:36:35Z"
last_edited: "2026-09-15T13:36:35Z"
---
# Implementation Tracking: runner

Build site: context/plans/build-site.md

| Task | Status | Notes |
|------|--------|-------|
| T-001 | DONE | config/default.php-cs-fixer.php: @Symfony, short arrays, risky off, Finder at getcwd(). php -l in image clean. |
| T-002 | DONE | bin/php-cs-fixer-docker skeleton: parse_args, resolve_project_root (git toplevel else PWD, pwd -P), EXIT_* constants, map_fixer_status (8→1, other→2). Verified root from root/subdir/outside repo. |
