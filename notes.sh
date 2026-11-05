#!/usr/bin/env bash
# Render grouped release notes for one tag range to a markdown file.
set -euo pipefail

repository="${REPOSITORY:?missing REPOSITORY}"
tag="${TAG:?missing TAG}"
output="${OUTPUT:?missing OUTPUT}"
server_url="${SERVER_URL:-https://github.com}"
contributors="${CONTRIBUTORS:-true}"
repository_url="${server_url}/${repository}"

previous_tag="${PREVIOUS_TAG:-}"
if [[ -z $previous_tag ]]; then
	previous_tag=$(git describe --tags --match "v[0-9]*" --abbrev=0 "${tag}^" 2>/dev/null || true)
fi
range="${previous_tag:+${previous_tag}..}${tag}"
log=$(git log --use-mailmap --reverse --format="%s%x1f%H%x1f%h%x1f%an%x1f%ae" "$range")

# Kept in a variable: an unquoted pattern with parens trips bash's `[[ =~ ]]` parser.
type_pattern='^([A-Za-z]+)(\([^)]*\))?!?:[[:space:]]*(.+)$'

rank_commits() {
	local subject full short name email type text rank login mention
	while IFS=$'\x1f' read -r subject full short name email; do
		type="other"
		text="$subject"
		if [[ $subject =~ $type_pattern ]]; then
			type="${BASH_REMATCH[1],,}"
			text="${BASH_REMATCH[3]}"
		fi
		mention=""
		if [[ $contributors != false && $name != *"[bot]"* ]]; then
			login=$(login_for "$email")
			[[ $login == *"[bot]" ]] || [[ -z $login ]] || mention="@$login"
		fi
		case "$type" in
		feat) rank=1 ;;
		fix) rank=2 ;;
		perf) rank=3 ;;
		refactor) rank=4 ;;
		style) rank=5 ;;
		docs) rank=6 ;;
		build) rank=7 ;;
		test) rank=8 ;;
		ci) rank=9 ;;
		chore) rank=10 ;;
		revert) rank=11 ;;
		*) rank=99 ;;
		esac
		printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$rank" "$type" "$text" "$short" "$full" "$mention"
	done
}

print_groups() {
	local rank type text short full mention current=""
	while IFS=$'\t' read -r rank type text short full mention; do
		if [[ $type != "$current" ]]; then
			[[ -z $current ]] || echo
			echo "#### $type"
			current=$type
		fi
		[[ -z $mention ]] || mention=" by $mention"
		echo "- $text [\`$short\`]($repository_url/commit/$full)$mention"
	done
}

# GitHub logins come from noreply emails, or from the API for other addresses.
declare -A logins=()

login_for() {
	local email=$1 login="" found
	if [[ -n ${logins[$email]+x} ]]; then
		printf '%s' "${logins[$email]}"
		return
	fi
	if [[ $email =~ ^([0-9]+\+)?([^@]+)@users\.noreply\.github\.com$ ]]; then
		login="${BASH_REMATCH[2]}"
	else
		found=$(gh api "repos/$repository/commits?author=${email//+/%2B}&per_page=1" \
			--jq ".[0].author.login" 2>/dev/null || true)
		[[ $found == null || -z $found ]] || login=$found
	fi
	logins[$email]=$login
	printf '%s' "$login"
}

notes=$({
	echo "### what's changed"
	echo
	rank_commits <<<"$log" | sort -s -t$'\t' -k1,1n -k2,2 | print_groups
	if [[ -n $previous_tag ]]; then
		echo
		echo "**full changelog:** [$previous_tag...$tag]($repository_url/compare/$previous_tag...$tag)"
	fi
})
printf '%s\n' "$notes" >"$output"

if [[ -n ${GITHUB_OUTPUT:-} ]]; then
	echo "path=$output" >>"$GITHUB_OUTPUT"
fi
printf '%s\n' "$output"
