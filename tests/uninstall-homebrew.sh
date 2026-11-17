#!/bin/bash
#
# Removes the runner image's Homebrew so the playbook installs it from scratch.
#
# Homebrew's official uninstall script deletes files one at a time and takes
# 1.5-2 minutes on a runner. On the arm64 runners it only removes the paths
# below, so remove them directly. /opt/homebrew is moved aside rather than
# deleted: a rename is instant, and the Homebrew role only needs the prefix to
# be missing or empty.
set -euo pipefail

if [ -d /opt/homebrew ]; then
  sudo mv /opt/homebrew /opt/homebrew.removed
fi

sudo rm -rf \
  /etc/paths.d/homebrew \
  "$HOME/Library/Caches/Homebrew" \
  "$HOME/Library/Logs/Homebrew" \
  /usr/local/Homebrew \
  /usr/local/Caskroom \
  /usr/local/bin/brew

# Fail fast if a brew is still reachable, e.g. a new runner image installs it
# somewhere else.
if command -v brew >/dev/null; then
  echo "brew still found at $(command -v brew)" >&2
  exit 1
fi
