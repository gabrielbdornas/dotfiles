#!/usr/bin/env bash
set -euo pipefail

echo "===> [2/3] System: installing system-level tools..."

# GitHub CLI moved to setup.sh (see docs/adr/0012) - gh needs to be
# installed and authenticated before we know $GITHUB_USERNAME, which now
# determines where the repo itself gets cloned, so it can't wait until
# after the clone anymore. Nothing else lives here yet; VS Code + extensions
# are still deferred per docs/adr/0008.

echo "===> System setup complete"
