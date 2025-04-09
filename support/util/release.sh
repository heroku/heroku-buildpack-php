#!/usr/bin/env bash

set -euo pipefail
shopt -s inherit_errexit

buildpack_registry_name="heroku/php"
github_repository_shorthand="heroku/heroku-buildpack-php"

function abort() {
	echo >&2
	echo >&2 "Error: ${1}"
	exit 1
}

echo >&2 "Checking environment..."

if ! command -v gh >/dev/null; then
	abort "Install the GitHub CLI first: https://cli.github.com"
fi

if ! heroku buildpacks:publish --help >/dev/null; then
	abort "Install the Buildpack Registry plugin first: https://github.com/heroku/plugin-buildpack-registry"
fi

echo >&2
echo >&2 "GitHub CLI user info for active account:"
if ! gh auth status --active; then
	abort "Log into the GitHub CLI first: gh auth login"
fi

echo >&2
echo >&2 "Heroku CLI user info for active account:"
# Explicitly check the CLI is logged in, since the Buildpack Registry plugin doesn't handle re-authing
# expired logins properly, which can otherwise lead to the release aborting partway through.
if ! heroku whoami; then
	abort "Log into the Heroku CLI first: heroku login"
fi

if [[ $(gh repo view --json "owner,name" --jq '(.owner.login +"/"+ .name)') != "$github_repository_shorthand" ]]; then
	abort "Local Git repository remote 'origin' is not ${github_repository_shorthand}"
fi

echo >&2
echo >&2 "Fetching releases from GitHub..."
current_github_release_version=$(gh release view --json tagName --jq '.tagName' | tr -d 'v')
new_version="$((current_github_release_version + 1))"
new_git_tag="v${new_version}"

echo "Current release Git tag is v${current_github_release_version}, new tag will be ${new_git_tag}"

echo >&2 "Extracting changelog entry for this release..."
git fetch origin
# Using `git show` to avoid having to disrupt the current branch/working directory.
changelog_entry="$(git show origin/main:CHANGELOG.md | awk "/^## \[v${new_version}\]/{flag=1; next} /^## /{flag=0} flag")"

if [[ -n "${changelog_entry}" ]]; then
	echo -e "${changelog_entry}\n"
else
	abort "Unable to find changelog entry for v${new_version}. Has the prepare release PR been triggered/merged?"
fi

read -r -p "Release on GitHub as tag '${new_git_tag}' and publish to Buildpack Registry buildpack '${buildpack_registry_name}' [y/n]? " choice
case "${choice}" in
	y | Y) ;;
	n | N) exit 0 ;;
	*) exit 1 ;;
esac

echo >&2
echo >&2 "Creating GitHub release and tag '${new_git_tag}'..."
gh release create "${new_git_tag}" --title "${new_git_tag}" --notes "${changelog_entry}"

echo >&2
echo >&2 "Publishing buildpack '${buildpack_registry_name}' using Git tag '${new_git_tag}' on Heroku Buildpack Registry..."
heroku buildpacks:publish "${buildpack_registry_name}" "${new_git_tag}" || abort "Failed to publish to Buildpack Registry.
See error message above for details.
Publishing can be re-attempted using the following command:
heroku buildpacks:publish ${buildpack_registry_name@Q} ${new_git_tag@Q}"
echo >&2
heroku buildpacks:versions "${buildpack_registry_name}" | head -n 3
