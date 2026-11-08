#!/bin/bash
# Classification and README checks for overview.py. Needs python3.
set -euo pipefail

cd "$(dirname "$0")"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

src=$tmp/data
mkdir -p "$src"/{cron,memories,kanban,.curator_cache,newdir} "$tmp/outside" "$tmp/bundled"
echo '{"jobs": {}}' >"$src/cron/jobs.json"
echo x >"$src/state.db"
echo x >"$src/newfile"
ln -s "$tmp/outside" "$src/linkdir"

lists='{"paths": [{"path": "cron/jobs.json", "description": "cron | jobs"},
                  {"path": "memories", "description": "memories"},
                  {"path": "kanban", "description": "both lists"}],
        "ignore": [{"reason": "databases", "patterns": ["*.db", "kanban"]},
                   {"reason": "caches", "patterns": ["*cache*"]}]}'
overview() { python3 -I ../files/state-export/overview.py "$src" "$tmp/bundled" v1 "$1" "$lists"; }

overview 2026-11-08T10:00:00Z </dev/null >"$tmp/r1"
unclassified=$(sed -n '/^## Unclassified$/,/^## Overview$/p' "$tmp/r1" | grep '^- ' || true)
[ "$unclassified" = $'- `linkdir`\n- `newdir/`\n- `newfile`' ] || fail "unclassified was: $unclassified"
grep -qxF '| `cron/jobs.json` | cron \| jobs |' "$tmp/r1" || fail "Exported row for cron/jobs.json"
grep -qxF '| `*.db`, `kanban` | databases |' "$tmp/r1" || fail "Ignored row for *.db, kanban"
[ "$(grep -c '^| 2026-11-08 10:00 |' "$tmp/r1")" = 1 ] || fail "first Overview row"
[ "$(grep '^## ' "$tmp/r1" | tr '\n' ' ')" = "## Unclassified ## Overview ## Exported ## Ignored " ] ||
  fail "section order: $(grep '^## ' "$tmp/r1" | tr '\n' ' ')"

overview 2026-11-08T11:00:00Z <"$tmp/r1" >"$tmp/r2"
cmp -s "$tmp/r1" "$tmp/r2" || fail "unchanged state changed the README"

mkdir "$src/another"
overview 2026-11-08T12:00:00Z <"$tmp/r2" >"$tmp/r3"
[ "$(diff "$tmp/r2" "$tmp/r3" | grep '^[<>]')" = '> - `another/`' ] || fail "new entry changed more than Unclassified"

rmdir "$src/another" "$src/newdir"
rm "$src/newfile" "$src/linkdir"
overview 2026-11-08T13:00:00Z <"$tmp/r3" >"$tmp/r4"
sed -n '/^## Unclassified$/,/^## Overview$/p' "$tmp/r4" | grep -qx 'None.' || fail "empty Unclassified"

mkdir "$src/$(printf 'x\n| Date (UTC) | Hermes |\nx')"
overview 2026-11-08T14:00:00Z <"$tmp/r4" >"$tmp/r5"
[ "$(grep -c '^| Date (UTC) |' "$tmp/r5")" = 1 ] || fail "entry name injected a table line"
[ "$(grep -c '^| 2026-11-08 10:00 |' "$tmp/r5")" = 1 ] || fail "Overview rows lost"

echo PASS
