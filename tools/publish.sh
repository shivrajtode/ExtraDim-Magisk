#!/usr/bin/env bash
# One command to put this repo on GitHub from Termux:   bash tools/publish.sh
#
#  1. works out your GitHub login (GitHub CLI "gh auth login", or a token)
#  2. fills the shivrajtode/ExtraDim-Magisk placeholders in README / docs / module.prop
#  3. rebuilds the tile app from app/ (Android 12+ needs app v1.1), builds the module zip
#  4. creates the repo (or updates it), pushes, sets description + topics
#  5. publishes a GitHub Release with the zip attached
# Safe to re-run: it updates instead of duplicating.
#
# Env overrides:
#   REPO=Name  OWNER=login  VISIBILITY=public|private  BRANCH=main
#   NO_APP=1   skip rebuilding the tile app (use the APK already in module/)
#   FORCE=1    force-push (only if the repo already holds unrelated history)
#
# Made with ❤️ by t.me/Shivraj_editx

set -u
cd "$(dirname "$0")/.." || exit 1

REPO=${REPO:-ExtraDim-Magisk}
VISIBILITY=${VISIBILITY:-public}
BRANCH=${BRANCH:-main}
DESC="Real Extra Dim for ROMs that lack it (Android 8 to 17+): colour-matrix dimming + Quick Settings tile, no overlay. Magisk module."
TOPICS="magisk magisk-module android extra-dim quick-settings-tile termux surfaceflinger root"
export GIT_TERMINAL_PROMPT=0

say()  { printf '\033[1;35m▸\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✔\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m✘ %s\033[0m\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

case "${1:-}" in -h|--help) sed -n '2,/^[^#]/p' "$0" | sed '$d;s/^# \{0,1\}//'; exit 0 ;; esac

# ---------------------------------------------------------------- tools
for t in git zip curl; do
  have "$t" || { have pkg && pkg install -y "$t" >/dev/null 2>&1; }
done
have git  || die "git is required (pkg install git)"
have zip  || die "zip is required (pkg install zip)"
have curl || die "curl is required (pkg install curl)"
have gh   || { have pkg && pkg install -y gh >/dev/null 2>&1; }   # optional

# ---------------------------------------------------------------- auth
MODE=""; TOKEN=""; TOKEN_FROM=""; CRED_USER=""
if have gh && gh auth status >/dev/null 2>&1; then
  MODE=gh
else
  TOKEN=${GITHUB_TOKEN:-${GH_TOKEN:-}}
  if [ -n "$TOKEN" ]; then
    TOKEN_FROM=env
  else
    CRED=$(printf 'protocol=https\nhost=github.com\n\n' | git credential fill 2>/dev/null || true)
    TOKEN=$(printf '%s\n' "$CRED" | sed -n 's/^password=//p' | head -n 1)
    CRED_USER=$(printf '%s\n' "$CRED" | sed -n 's/^username=//p' | head -n 1)
    [ -n "$TOKEN" ] && TOKEN_FROM=git
  fi
  [ -n "$TOKEN" ] && MODE=token
fi
[ -n "$MODE" ] || die "No GitHub login found. Run:  gh auth login   (or export GITHUB_TOKEN=...)"

api() { # METHOD PATH [JSON]
  if [ -n "${3:-}" ]; then
    curl -sS -X "$1" -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" -d "$3" "https://api.github.com$2"
  else
    curl -sS -X "$1" -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" "https://api.github.com$2"
  fi
}

OWNER=${OWNER:-}
if [ -z "$OWNER" ]; then
  if [ "$MODE" = gh ]; then
    OWNER=$(gh api user -q .login 2>/dev/null || true)
  else
    OWNER=$(api GET /user | sed -n 's/.*"login": *"\([^"]*\)".*/\1/p' | head -n 1)
    [ -n "$OWNER" ] || OWNER=$CRED_USER
  fi
fi
[ -n "$OWNER" ] || die "Could not work out your GitHub username (run again with OWNER=yourname)"
ok "GitHub account: $OWNER  (auth: $MODE)  ->  $OWNER/$REPO ($VISIBILITY)"

# ---------------------------------------------------------------- placeholders
say "Personalising README / docs for $OWNER/$REPO"
FILES=$(grep -rIl -e 'shivrajtode' -e 'ExtraDim-Magisk' -e 'main' . --exclude-dir=.git --exclude-dir=dist 2>/dev/null || true)
for f in $FILES; do
  sed -i "s|shivrajtode|$OWNER|g; s|ExtraDim-Magisk|$REPO|g; s|main|$BRANCH|g" "$f"
done

# ---------------------------------------------------------------- build
say "Building the module zip"
APPFLAG="--app"; [ "${NO_APP:-0}" = 1 ] && APPFLAG=""
OWNER="$OWNER" REPO="$REPO" BRANCH="$BRANCH" bash tools/build.sh $APPFLAG || die "build failed"
ZIP=$(ls -t dist/*.zip 2>/dev/null | head -n 1)
[ -n "$ZIP" ] || die "no zip in dist/"
VERSION=$(sed -n 's/^version=//p' module/module.prop | head -n 1)

# ---------------------------------------------------------------- git
say "Committing"
if [ ! -d .git ]; then
  git init -q -b "$BRANCH" 2>/dev/null || { git init -q; git symbolic-ref HEAD "refs/heads/$BRANCH"; }
fi
git config user.name  >/dev/null 2>&1 || git config user.name "$OWNER"
git config user.email >/dev/null 2>&1 || git config user.email "$OWNER@users.noreply.github.com"
git add -A
if git diff --cached --quiet 2>/dev/null; then
  say "nothing new to commit"
else
  git commit -q -m "Extra Dim $VERSION" && ok "committed"
fi

# ---------------------------------------------------------------- repo
exists=0
if [ "$MODE" = gh ]; then
  gh repo view "$OWNER/$REPO" >/dev/null 2>&1 && exists=1
  gh auth setup-git >/dev/null 2>&1 || true
else
  code=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $TOKEN" "https://api.github.com/repos/$OWNER/$REPO")
  [ "$code" = 200 ] && exists=1
fi
if [ "$exists" = 0 ]; then
  say "Creating $OWNER/$REPO"
  if [ "$MODE" = gh ]; then
    gh repo create "$OWNER/$REPO" "--$VISIBILITY" --description "$DESC" >/dev/null || die "repo creation failed"
  else
    priv=false; [ "$VISIBILITY" = private ] && priv=true
    api POST /user/repos "{\"name\":\"$REPO\",\"description\":\"$DESC\",\"private\":$priv}" \
      | grep -q '"full_name"' || die "repo creation failed (the token needs the 'repo' scope)"
  fi
else
  say "$OWNER/$REPO already exists - updating it"
fi

ORIGIN=${ORIGIN_URL:-https://github.com/$OWNER/$REPO.git}
if git remote get-url origin >/dev/null 2>&1; then git remote set-url origin "$ORIGIN"; else git remote add origin "$ORIGIN"; fi

GITAUTH=()
if [ "$MODE" = token ] && [ "$TOKEN_FROM" = env ]; then
  GITAUTH=(-c "http.extraHeader=Authorization: Basic $(printf 'x-access-token:%s' "$TOKEN" | base64 | tr -d '\n')")
fi
g() { git ${GITAUTH[@]+"${GITAUTH[@]}"} "$@"; }

# Several devices can publish the same repo: continue from the history that is already on GitHub
# (so the push is a plain fast-forward) instead of starting a new one on every device.
if [ "$exists" = 1 ] && [ "${FORCE:-0}" != 1 ]; then
  if g fetch -q origin "$BRANCH" 2>/dev/null; then
    if git merge-base --is-ancestor FETCH_HEAD HEAD 2>/dev/null; then
      :
    else
      say "Continuing from the history already on GitHub"
      git reset -q --soft FETCH_HEAD
      if git diff --cached --quiet; then
        say "GitHub already has exactly this content"
      else
        git commit -q -m "Extra Dim $VERSION" && ok "committed on top of the existing history"
      fi
    fi
  else
    warn "could not read $BRANCH from GitHub (empty repo?) - pushing as is"
  fi
fi

say "Pushing $BRANCH"
PUSH=(push -u origin "$BRANCH")
[ "${FORCE:-0}" = 1 ] && PUSH=(push --force -u origin "$BRANCH")
g "${PUSH[@]}" || die "push failed (gh users: gh auth setup-git; if the repo already holds unrelated files, re-run with FORCE=1)"
ok "pushed"

# ---------------------------------------------------------------- description + topics
if [ "$MODE" = gh ]; then
  gh repo edit "$OWNER/$REPO" --description "$DESC" >/dev/null 2>&1 || warn "could not set the description"
  for t in $TOPICS; do gh repo edit "$OWNER/$REPO" --add-topic "$t" >/dev/null 2>&1 || true; done
else
  names=$(printf '"%s",' $TOPICS | sed 's/,$//')
  api PATCH "/repos/$OWNER/$REPO" "{\"description\":\"$DESC\"}" >/dev/null 2>&1 || warn "could not set the description"
  api PUT "/repos/$OWNER/$REPO/topics" "{\"names\":[$names]}" >/dev/null 2>&1 || warn "could not set the topics"
fi

# ---------------------------------------------------------------- release
TAG=$VERSION
NOTES=docs/RELEASE_NOTES.md
say "Publishing release $TAG"
if [ "$MODE" = gh ]; then
  if gh release view "$TAG" -R "$OWNER/$REPO" >/dev/null 2>&1; then
    gh release upload "$TAG" "$ZIP" --clobber -R "$OWNER/$REPO" >/dev/null && ok "release $TAG: zip updated" || warn "could not update the release asset"
  else
    gh release create "$TAG" "$ZIP" -R "$OWNER/$REPO" --target "$BRANCH" --title "Extra Dim $TAG" \
      --notes-file "$NOTES" >/dev/null && ok "release $TAG published" || warn "could not create the release"
  fi
else
  rel=$(api GET "/repos/$OWNER/$REPO/releases/tags/$TAG")
  id=$(printf '%s' "$rel" | sed -n 's/^  "id": *\([0-9][0-9]*\),.*/\1/p' | head -n 1)
  if [ -z "$id" ]; then
    body=$(sed ':a;N;$!ba;s/\\/\\\\/g;s/"/\\"/g;s/\r//g;s/\n/\\n/g;s/\t/\\t/g' "$NOTES")
    rel=$(api POST "/repos/$OWNER/$REPO/releases" "{\"tag_name\":\"$TAG\",\"target_commitish\":\"$BRANCH\",\"name\":\"Extra Dim $TAG\",\"body\":\"$body\"}")
    id=$(printf '%s' "$rel" | sed -n 's/^  "id": *\([0-9][0-9]*\),.*/\1/p' | head -n 1)
  fi
  if [ -n "$id" ]; then
    name=$(basename "$ZIP")
    curl -sS -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/zip" \
      --data-binary @"$ZIP" "https://uploads.github.com/repos/$OWNER/$REPO/releases/$id/assets?name=$name" \
      | grep -q '"browser_download_url"' \
      && ok "release $TAG published with $name" \
      || warn "zip upload failed (if an asset named $name already exists, delete it on GitHub and re-run)"
  else
    warn "could not create the release"
  fi
fi

URL=https://github.com/$OWNER/$REPO
echo
ok "Done  ->  $URL"
echo "   Releases : $URL/releases"
echo "   Optional : upload assets/social-preview.png in Settings -> General -> Social preview"
echo "              (GitHub only allows that from the website)"
