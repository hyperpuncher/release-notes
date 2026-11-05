#!/usr/bin/env bash
# Check grouping, subject handling, and the range boundaries against a fixture repo.
set -euo pipefail

cd "$(dirname "$0")/.."
notes=$PWD/notes.sh

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
repo="$tmp/repo"
git init -q "$repo"

commit() {
	GIT_AUTHOR_NAME="$1" GIT_AUTHOR_EMAIL="$2" \
		GIT_COMMITTER_NAME="$1" GIT_COMMITTER_EMAIL="$2" \
		git -C "$repo" commit -q --allow-empty -m "$3"
}

commit "alice" "123+alice@users.noreply.github.com" "chore: start"
git -C "$repo" tag v0.1.0
commit "alice" "123+alice@users.noreply.github.com" "feat(ui)!: break the api"
commit "alice" "123+alice@users.noreply.github.com" "fix: keep the shade"
commit "bob" "456+bob@users.noreply.github.com" "docs: explain the thing"
commit "alice" "123+alice@users.noreply.github.com" "no prefix at all"
commit "alice" "123+alice@users.noreply.github.com" "chore(deps): bump the thing"
commit "alice" "123+alice@users.noreply.github.com" "revert: undo the thing"
git -C "$repo" tag v0.2.0

render() {
	(cd "$repo" && REPOSITORY=test/repo TAG="$1" OUTPUT="$tmp/notes.md" CONTRIBUTORS="$2" \
		bash "$notes" >/dev/null)
	# Hashes and links vary per run, the shape is what matters.
	# shellcheck disable=SC2016 # the pattern is a literal regex, not a shell expansion
	sed -E 's/\[`[0-9a-f]+`\]\([^)]*\)/[sha]/' "$tmp/notes.md"
}

diff -u <(render v0.2.0 false) - <<'EOF'
### what's changed

#### feat
- break the api [sha]

#### fix
- keep the shade [sha]

#### docs
- explain the thing [sha]

#### chore
- bump the thing [sha]

#### revert
- undo the thing [sha]

#### other
- no prefix at all [sha]

**full changelog:** [v0.1.0...v0.2.0](https://github.com/test/repo/compare/v0.1.0...v0.2.0)
EOF

diff -u <(render v0.1.0 false) - <<'EOF'
### what's changed

#### chore
- start [sha]
EOF

diff -u <(render v0.2.0 true) - <<'EOF'
### what's changed

#### feat
- break the api [sha] by @alice

#### fix
- keep the shade [sha] by @alice

#### docs
- explain the thing [sha] by @bob

#### chore
- bump the thing [sha] by @alice

#### revert
- undo the thing [sha] by @alice

#### other
- no prefix at all [sha] by @alice

**full changelog:** [v0.1.0...v0.2.0](https://github.com/test/repo/compare/v0.1.0...v0.2.0)
EOF

echo "release notes: passed"
