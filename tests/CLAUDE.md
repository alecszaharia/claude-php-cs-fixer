# Tests

`verify.sh` is the self-verification script (fixture check/fix, ownership, config precedence, preflight causes, version-image mapping). Run `bash tests/verify.sh`; exit 0 means all assertions passed.

Implements:
- cavekit-plugin.md R7 (Self-verification fixture), R6.3 (version-image assertion), R4 (bundled, offline)

Build tasks: T-012, T-013 (build-site.md)
