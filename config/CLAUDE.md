# Bundled Config

`default.php-cs-fixer.php` applies only when the project has no php-cs-fixer config. Mounted read-only outside the project; uses `getcwd()`, never `__DIR__`.

Implements:
- cavekit-runner.md R4 (Config resolution, bundled default)

Build tasks: T-001 (build-site.md)
