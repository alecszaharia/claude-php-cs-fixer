# Runtime probe: ghcr.io/php-cs-fixer/php-cs-fixer:3.95.25-php8.5 (2026-09-15, this host)

Command shape verified working:
  docker run --rm --user "$(id -u):$(id -g)" -v "$P:$P" -w "$P" \
    -v "<plugin>/config/default.php-cs-fixer.php:/opt/php-cs-fixer/default.php:ro" \
    IMG fix [--dry-run --diff] --config=/opt/php-cs-fixer/default.php <paths>

Observed:
- `fix --dry-run --diff` with violations → exit 8; stdout has per-file "1) src/Foo.php", "begin diff / end diff" blocks with host absolute paths, and "Found 1 of 1 files that can be fixed in ...".
- `fix` → exit 0; "Fixed 1 of 1 files in ..."; file and `.php-cs-fixer.cache` owned by host uid:gid 1000:1000.
- Clean dry-run → exit 0; "Found 0 of 1 files that can be fixed".
- Second run prints `Using cache file ".php-cs-fixer.cache".` (no -v needed once cache exists).
- `--format=json` → {"about":..., "files":[{"name":"src/Foo.php"}], "time":..., "memory":...}; with --diff each file entry gains a "diff" key. Deterministic for counting changed files.
- "Loaded config default from \"/opt/cs/default.php\"" line appears in text output → usable to echo config source, but runner should print its own `config:` label regardless.
- Passing explicit paths prints "Paths from configuration have been overridden by paths provided as command arguments." (informational).
- Warning printed when project has no composer.json: "Unable to determine minimum PHP version supported by your project from composer.json: Failed to read file \"composer.json\"." Cosmetic (stderr). Not an error.
- `IMG --version` → "PHP CS Fixer 3.95.25 Adalbertus ... PHP runtime: 8.5.10".
- php-cs-fixer exit code bits: 1 general error, 4 invalid syntax in some files, 8 files need fixing (dry-run), 16 config error, 32 fixer config error, 64 exception.

Bundled default config that worked (Finder rooted at getcwd(), i.e. P):
  return (new PhpCsFixer\Config())->setRiskyAllowed(false)
    ->setRules(['@Symfony' => true, 'array_syntax' => ['syntax' => 'short']])
    ->setFinder((new PhpCsFixer\Finder())->in(getcwd())->exclude(['vendor', 'var']));
