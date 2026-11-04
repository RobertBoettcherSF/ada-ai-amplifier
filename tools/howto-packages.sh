#!/bin/sh
# Packages named in docs/HOWTO.md. The CI job "how-to steps" runs this
# before tools/howto-steps.sh. The guide quotes this file.
set -e
sudo DEBIAN_FRONTEND=noninteractive apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  rpm2cpio cpio lld libedit2
wget -q -O /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y /tmp/chrome.deb
