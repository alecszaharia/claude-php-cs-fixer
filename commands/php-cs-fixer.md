---
description: Run php-cs-fixer (check or fix) on PHP files inside a pinned Docker image. No host PHP needed.
argument-hint: "<check|fix> [paths...] [-- php-cs-fixer flags]"
allowed-tools: Bash
---

Run php-cs-fixer through the bundled runner. This command is a thin shell over
`bin/php-cs-fixer-docker`; it adds nothing and hides nothing.

Execute exactly this one Bash command, passing the user's arguments through
verbatim (do not re-quote, reorder, drop, or add arguments; an empty argument
list is valid and means "git working-set scope"):

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/php-cs-fixer-docker" $ARGUMENTS
```

Then present the command's stdout, stderr, and exit status to the user as they
are.

Contract of the runner (for your understanding, not for rewriting its output):

- Operations: `check` (dry-run, prints a diff, exit 1 when violations exist) and
  `fix` (rewrites files in place). There are no other operations.
- Paths: optional; default is the git working set (modified, staged, untracked
  `.php` files) of the current repository. Explicit paths must lie under the
  project root.
- Everything after `--` is forwarded to php-cs-fixer unchanged.
- Output: `config:`, `files_processed:`, `files_changed:` lines, then one
  absolute path per affected file, then for `check` a `--- diff ---` line
  followed by the unified diff.
- Exit status: 0 ok, 1 violations found, 2 tool or preflight error (Docker
  missing, daemon unreachable, image pull failed, no scope, invalid path, or a
  php-cs-fixer failure whose own output is shown verbatim).

Rules:

- Do not invent operations or flags beyond what the user typed.
- Do not summarize, reformat, truncate, or reorder the runner's summary or diff.
- Do not replace a preflight error line with a generic failure message; show
  the runner's line.
- Do not retry a failing run by editing project files, installing PHP tooling on
  the host, or changing the Docker setup. Report the failure and stop.
