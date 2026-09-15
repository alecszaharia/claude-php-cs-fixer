#!/usr/bin/env bash
# Self-verification for the php-cs-fixer plugin. Exits 0 only when every
# assertion passed. Never prompts. Requires Docker; the pinned image is pulled
# on first run.
set -u

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
plugin_root="${CLAUDE_PLUGIN_ROOT:-$repo_root}"
runner="$plugin_root/bin/php-cs-fixer-docker"
fixture="$repo_root/tests/fixture/Sample.php"

pass=0; fail=0; skipped=0
ok()   { pass=$((pass + 1)); printf 'ok   %s\n' "$1"; }
bad()  { fail=$((fail + 1)); printf 'FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '     %s\n' "$2"; }
skip() { skipped=$((skipped + 1)); printf 'SKIP %s\n' "$1"; }
assert() { # assert <description> <command...>   (command run via eval-free "$@")
    local desc=$1; shift
    if "$@" >/dev/null 2>&1; then ok "$desc"; else bad "$desc"; fi
}

work=$(mktemp -d "$repo_root/.verify-XXXXXX") || { echo "cannot create work dir"; exit 2; }
trap 'rm -rf "$work"' EXIT
# The work dir is its own git repository so the runner resolves it (not this
# repo) as the project root: cache, config lookup and scope all land there.
git init -q "$work"
mkdir -p "$work/src"
cp "$fixture" "$work/src/Sample.php"
fixture_sha_before=$(sha256sum "$fixture" | cut -d' ' -f1)
git_status_before=$(git -C "$repo_root" --no-pager status --porcelain)

# ---------------------------------------------------------------- plugin R4.1: runner ships complete
assert "runner script present in plugin"        test -x "$runner"
assert "bundled default config present"         test -f "$plugin_root/config/default.php-cs-fixer.php"
assert "plugin manifest present"                test -f "$plugin_root/.claude-plugin/plugin.json"

# ---------------------------------------------------------------- plugin R7.2 / runner R6.2: check on the pristine fixture
out=$("$runner" check "$fixture" -- --using-cache=no 2>&1); rc=$?
assert "check on fixture exits 1 (violations)"  test "$rc" -eq 1
assert "check output lists the fixture path"    grep -qx "$fixture" <<<"$out"
assert "exactly one --- diff --- delimiter"     test "$(grep -c '^--- diff ---$' <<<"$out")" -eq 1
assert "diff section mentions the fixture"      grep -q "Sample.php" <(sed -n '/^--- diff ---$/,$p' <<<"$out")
assert "summary carries fixed labels"           grep -qE '^config: .+' <<<"$out"
assert "files_processed label present"          grep -qE '^files_processed: [0-9]+$' <<<"$out"
assert "files_changed label present"            grep -qE '^files_changed: [0-9]+$' <<<"$out"
assert "fixture untouched by check"             test "$(sha256sum "$fixture" | cut -d' ' -f1)" = "$fixture_sha_before"
assert "long array syntax is flagged"           grep -q '^-.*array(' <<<"$out"
assert "no declare(strict_types) added (non-risky)" bash -c '! grep -q "strict_types" <<<"$1"' _ "$out"

# ---------------------------------------------------------------- plugin R7.3 / runner R6.1, R6.3: fix a disposable copy, then re-check clean
(cd "$work" && "$runner" fix src/Sample.php >/dev/null 2>&1); rc=$?
assert "fix on copy exits 0"                    test "$rc" -eq 0
out=$(cd "$work" && "$runner" check src/Sample.php 2>&1); rc=$?
assert "re-check on fixed copy exits 0"         test "$rc" -eq 0
assert "re-check reports zero changes"          grep -qx 'files_changed: 0' <<<"$out"
assert "re-check has no diff delimiter"         bash -c '! grep -q "^--- diff ---$" <<<"$1"' _ "$out"

# ---------------------------------------------------------------- runner R6.5: cache created and survives a second run
assert "cache file created at project root"     test -f "$work/.php-cs-fixer.cache"
(cd "$work" && "$runner" check src/Sample.php >/dev/null 2>&1)
assert "cache file survives second run"         test -f "$work/.php-cs-fixer.cache"
out=$(cd "$work" && "$runner" check src/Sample.php -- --verbose 2>&1 >/dev/null)
assert "verbose run reports cache use"          grep -q 'Using cache file' <<<"$out"

# ---------------------------------------------------------------- runner R3.1-R3.3: ownership (Linux only)
if [ "$(uname -s)" = Linux ]; then
    me="$(id -u):$(id -g)"
    assert "rewritten file owned by invoker"    test "$(stat -c '%u:%g' "$work/src/Sample.php")" = "$me"
    assert "cache owned by invoker"             test "$(stat -c '%u:%g' "$work/.php-cs-fixer.cache")" = "$me"
    assert "nothing root-owned in work dir"     test -z "$(find "$work" -user 0 2>/dev/null)"
else
    skip "ownership assertions (macOS: Docker Desktop maps ownership; inspect run_fixer's Darwin branch)"
fi

# ---------------------------------------------------------------- runner R4.1, R4.2, R4.4: config precedence via the config: line
cfg='<?php return (new PhpCsFixer\Config())->setRules([])->setFinder(PhpCsFixer\Finder::create()->in(__DIR__));'
printf '%s\n' "$cfg" > "$work/.php-cs-fixer.dist.php"
out=$(cd "$work" && "$runner" check src/Sample.php 2>&1)
assert "dist config labelled when alone"        grep -qx "config: project ($work/.php-cs-fixer.dist.php)" <<<"$out"
printf '%s\n' "$cfg" > "$work/.php-cs-fixer.php"
out=$(cd "$work" && "$runner" check src/Sample.php 2>&1)
assert ".php-cs-fixer.php wins over dist"       grep -qx "config: project ($work/.php-cs-fixer.php)" <<<"$out"
rm -f "$work/.php-cs-fixer.php" "$work/.php-cs-fixer.dist.php"
out=$(cd "$work" && "$runner" check src/Sample.php 2>&1)
assert "bundled default labelled when none"     grep -q '^config: bundled default' <<<"$out"

# ---------------------------------------------------------------- runner R1.3, R1.4: image pinned once, stable
assert "image reference appears exactly once"   test "$(grep -c 'ghcr.io/php-cs-fixer' "$runner")" -eq 1
img1=$(PHPCSFIXER_DEBUG_ARGS=1 "$runner" check | sed -n 's/^image=//p')
img2=$(PHPCSFIXER_DEBUG_ARGS=1 "$runner" check | sed -n 's/^image=//p')
assert "image reference stable across runs"     test -n "$img1" -a "$img1" = "$img2"
assert "image reference carries explicit tag"   bash -c '[[ "$1" == *:* && "$1" != *:latest ]]' _ "$img1"

# ---------------------------------------------------------------- plugin R6.3: version <-> image tag mapping
version=$(node -e 'process.stdout.write(require(process.argv[1]).version)' "$plugin_root/.claude-plugin/plugin.json" 2>/dev/null \
    || sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$plugin_root/.claude-plugin/plugin.json" | head -1)
mapped=$(sed -n "s/^- $version: //p" "$plugin_root/CHANGELOG.md" | head -1)
assert "CHANGELOG maps current version to an image" test -n "$mapped"
assert "mapped image equals runner image"       test "$mapped" = "$img1"
mkt_version=$(node -e 'process.stdout.write(require(process.argv[1]).plugins[0].version)' "$plugin_root/.claude-plugin/marketplace.json" 2>/dev/null)
assert "marketplace version matches plugin.json" test "$mkt_version" = "$version"

# ---------------------------------------------------------------- plugin R4.3: no run-time fetching (inspection)
assert "no network-fetch instructions in runner/command/skill" \
    bash -c '! grep -nE "^[^#]*\b(curl|wget|git clone|git fetch|scp|npm i|composer install)\b" "$@"' _ \
    "$runner" "$plugin_root/commands/php-cs-fixer.md" "$plugin_root/skills/php-cs-fixer/SKILL.md"

# ---------------------------------------------------------------- plugin R2.5: no hooks
assert "no hooks directory"                     test ! -e "$plugin_root/hooks"
assert "no hooks key in plugin.json"            bash -c '! grep -q "\"hooks\"" "$1"' _ "$plugin_root/.claude-plugin/plugin.json"

# ---------------------------------------------------------------- plugin R4.2: offline run with image present
if command -v unshare >/dev/null 2>&1 && unshare -rn true 2>/dev/null; then
    out=$(cd "$work" && unshare -rn "$runner" check src/Sample.php 2>&1); rc=$?
    assert "check completes with host networking disabled" test "$rc" -eq 0
else
    skip "offline check (unshare -rn unavailable or denied)"
fi

# ---------------------------------------------------------------- runner R8, plugin R5: preflight causes, distinct, no file changes
snap_before=$(cd "$work" && find . -type f -exec sha256sum {} + | sort)
m_cli=$(cd "$work" && env PATH=/nonexistent /bin/bash "$runner" check src/Sample.php 2>&1); rc_cli=$?
m_daemon=$(cd "$work" && DOCKER_HOST=unix:///nonexistent/docker.sock "$runner" check src/Sample.php 2>&1); rc_daemon=$?
m_pull_full=$(cd "$work" && PHPCSFIXER_IMAGE_OVERRIDE=ghcr.io/php-cs-fixer/php-cs-fixer:0.0.0-does-not-exist "$runner" check src/Sample.php 2>&1); rc_pull=$?
m_pull=$(head -1 <<<"$m_pull_full")
nogit=$(mktemp -d)
m_scope=$(cd "$nogit" && "$runner" check 2>&1); rc_scope=$?
rmdir "$nogit"
assert "docker-CLI-absent exits 2"              test "$rc_cli" -eq 2
assert "docker-CLI-absent is one line"          test "$(wc -l <<<"$m_cli")" -eq 1
assert "daemon-unreachable exits 2"             test "$rc_daemon" -eq 2
assert "daemon-unreachable is one line"         test "$(wc -l <<<"$m_daemon")" -eq 1
assert "pull-failure exits 2"                   test "$rc_pull" -eq 2
assert "no-scope exits 2"                       test "$rc_scope" -eq 2
assert "no-scope is one line"                   test "$(wc -l <<<"$m_scope")" -eq 1
assert "four preflight causes are distinct"     test "$(printf '%s\n' "$m_cli" "$m_daemon" "$m_pull" "$m_scope" | sort -u | wc -l)" -eq 4
assert "preflight failures touched no file"     test "$(cd "$work" && find . -type f -exec sha256sum {} + | sort)" = "$snap_before"
m_badpath=$(cd "$work" && "$runner" check /etc 2>&1); rc_badpath=$?
assert "out-of-root path exits 2 and names it"  bash -c '[ "$1" -eq 2 ] && grep -q "/etc" <<<"$2"' _ "$rc_badpath" "$m_badpath"
m_nopath=$(cd "$work" && "$runner" check nope.php 2>&1); rc_nopath=$?
assert "missing path exits 2 and names it"      bash -c '[ "$1" -eq 2 ] && grep -q "nope.php" <<<"$2"' _ "$rc_nopath" "$m_nopath"

# ---------------------------------------------------------------- plugin R7.5: tree unchanged
assert "fixture byte-identical after run"       test "$(sha256sum "$fixture" | cut -d' ' -f1)" = "$fixture_sha_before"
assert "git working tree unchanged"             test "$(git -C "$repo_root" --no-pager status --porcelain)" = "$git_status_before"

printf '\n%d passed, %d failed, %d skipped\n' "$pass" "$fail" "$skipped"
[ "$fail" -eq 0 ]
