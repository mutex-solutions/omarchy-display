#!/usr/bin/env bash
# Install (or remove) the root half of the Re-detect button: a helper in
# /usr/local/libexec and the polkit action that lets pkexec run it. The plugin
# itself is a user plugin and cannot install these; the button stays hidden
# until they exist.
#
#   bash scripts/install-redetect.sh            # install / update
#   bash scripts/install-redetect.sh --remove   # uninstall
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

helper=/usr/local/libexec/omarchy-display-redetect
policy=/usr/share/polkit-1/actions/com.mutex-solutions.display.redetect.policy

if [[ ${1:-} == --remove ]]; then
  sudo rm -f "$helper" "$policy"
  echo "removed $helper and $policy"
  exit 0
fi

# root-owned and not writable by the user: pkexec runs it as root.
sudo install -Dm755 -o root -g root system/omarchy-display-redetect "$helper"
sudo install -Dm644 -o root -g root system/com.mutex-solutions.display.redetect.policy "$policy"
echo "installed $helper and $policy"
