#!/bin/bash
# This script is used by CI setup to update add-on name in manifest
# to explicitly state that produced artifact is a dev build.
set -e

MANIFEST=add-on/manifest.json

# restore original (make this script immutable)
git checkout $MANIFEST

# Use jq for JSON operations
function set-manifest {
  jq -M --indent 2 "$1" < $MANIFEST > tmp.json && mv tmp.json $MANIFEST
}

## Set NAME
# Name includes git revision to make QA and bug reporting easier for users :-)
REVISION=$(git show-ref --head HEAD | head -c 7)
set-manifest ".name = \"IPFS Companion (Dev Build @ $REVISION)\""
grep $REVISION $MANIFEST

## Set VERSION
# Browsers do not accept non-numeric values in version string
# so we calculate some sub-versions based on number of commits in master and  current branch
COMMITS_IN_MASTER=$(git rev-list --count refs/remotes/origin/master)
NEW_COMMITS_IN_CURRENT_BRANCH=$(git rev-list --count HEAD ^refs/remotes/origin/master)
# mozilla/addons-linter: Version string must be a string comprising one to four dot-separated integers (0-65535). E.g: 1.2.3.4"
BUILD_VERSION=$(($COMMITS_IN_MASTER*10+$NEW_COMMITS_IN_CURRENT_BRANCH))
set-manifest ".version = (.version + \".${BUILD_VERSION}\")"
grep \"version\" $MANIFEST

# addon-linter throws error on 'update_url' so it is disabled in dev build
# and needs to be manually opted-in when beta build is run
if [ "$1" == "firefox-beta" ]; then
    # Switch to self-hosted dev-build for Firefox (https://github.com/ipfs-shipyard/ipfs-companion/issues/385)
    DEV_BUILD_ADDON_ID="ipfs-companion-dev-build@ci.ipfs.team"
    UPDATE_URL="https://ipfs-shipyard.github.io/ipfs-companion/ci/firefox/update.json"

    ## Set ADD-ON ID
    set-manifest ".applications.gecko[\"id\"] = \"$DEV_BUILD_ADDON_ID\""
    grep ipfs-companion-dev-build $MANIFEST

    ## Add UPDATE_URL
    set-manifest ".applications.gecko[\"update_url\"] = \"$UPDATE_URL\""
    grep update_url $MANIFEST
fi
