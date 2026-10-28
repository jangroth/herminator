#!/bin/bash
# One export run: mirror allowlisted state into the work tree, scan, commit, push.
set -euo pipefail

SRC=${STATE_EXPORT_SOURCE:-/opt/data}
BUNDLED=${STATE_EXPORT_BUNDLED_SKILLS:-/opt/hermes/skills}
WORK=${STATE_EXPORT_WORKTREE:-/work/repo}
REMOTE=${STATE_EXPORT_REMOTE:?}
BRANCH=${STATE_EXPORT_BRANCH:-main}
BETTERLEAKS=${STATE_EXPORT_BETTERLEAKS:-/tools/betterleaks}
PATHS=${STATE_EXPORT_PATHS:?}
TAG=${HERMES_IMAGE_TAG:?}
NOW=$(date -u +%FT%TZ)

log() { printf '%s %s\n' "$(date -u +%FT%TZ)" "$*" >&2; }

# Hermes owns $SRC; no path component may be a symlink, or the copy could
# resolve it inside this container (e.g. to the deploy key).
has_symlink() {
  local p=$SRC part
  local -a parts
  IFS=/ read -ra parts <<<"$1"
  for part in "${parts[@]}"; do
    p=$p/$part
    [[ -L $p ]] && return 0
  done
  return 1
}

copy_file() {
  local rel=$1
  [[ $rel == *.lock ]] && return 0
  mkdir -p "$WORK/$(dirname "$rel")"
  cp -P --preserve=mode -- "$SRC/$rel" "$WORK/$rel"
}

copy_path() {
  local rel=$1 src=$SRC/$1 f
  local -a prune=(-name .git -o -name __pycache__)
  # Skill metadata (.hub, .archive, .bundled_manifest, ...) isn't skill content.
  [[ $rel == skills || $rel == skills/* ]] && prune=(-name '.*' -o -name __pycache__)
  if [[ -z $rel || $rel == /* || /$rel/ == */../* ]]; then
    log "invalid path: $rel"
    return 1
  fi
  if has_symlink "$rel"; then
    log "skipped symlink: $rel"
    return 0
  fi
  if [[ -f $src ]]; then
    copy_file "$rel"
  elif [[ -d $src ]]; then
    while IFS= read -r -d '' f; do
      log "skipped symlink: ${f#"$SRC"/}"
    done < <(find "$src" -type l -print0)
    while IFS= read -r -d '' f; do
      copy_file "${f#"$SRC"/}"
    done < <(find "$src" \( "${prune[@]}" \) -prune -o -type f -print0)
  else
    log "missing: $rel"
  fi
}

ahead() {
  local head
  head=$(git -C "$WORK" rev-parse -q --verify HEAD) || return 1
  [[ $head != "$(git -C "$WORK" rev-parse -q --verify "refs/remotes/origin/$BRANCH" || true)" ]]
}

if [[ ! -d $WORK/.git ]]; then
  git clone -q "$REMOTE" "$WORK"
  git -C "$WORK" symbolic-ref HEAD "refs/heads/$BRANCH"
fi

find "$WORK" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
while IFS= read -r p; do
  [[ -n $p ]] && copy_path "$p"
done <<<"$PATHS"
python3 -I "$(dirname "$0")/overview.py" "$SRC" "$BUNDLED" "$TAG" "$NOW" \
  < <(git -C "$WORK" show HEAD:README.md 2>/dev/null) >"$WORK/README.md"
# Catches files swapped for symlinks between find and cp.
find "$WORK" -type l ! -path "$WORK/.git/*" -print -delete

git -C "$WORK" add -A
if ! git -C "$WORK" diff --cached --quiet; then
  rc=0
  (cd "$WORK" && "$BETTERLEAKS" git --staged --no-banner --no-color --redact \
    --ignore-gitleaks-allow --exit-code 3 -v .) || rc=$?
  case $rc in
    0) ;;
    3) log "secret scan reported findings; not committing"; exit 1 ;;
    *) log "secret scan failed (exit $rc); not committing"; exit 1 ;;
  esac
  git -C "$WORK" -c user.name=hermes-state-export \
    -c user.email=hermes-state-export@users.noreply.github.com \
    commit -q -m "export $NOW (hermes $TAG)"
fi

if ahead; then
  git -C "$WORK" push -q origin "HEAD:refs/heads/$BRANCH"
  log "pushed $(git -C "$WORK" rev-parse --short HEAD)"
else
  log "no changes"
fi
