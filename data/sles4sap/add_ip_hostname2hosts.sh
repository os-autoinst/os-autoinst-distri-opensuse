#!/bin/bash
#
# Summary: script to add local ip and hostname into /etc/hosts
# Maintainer: Alvaro Carvajal <acarvajal@suse.de>

set -x
echo "$(ip -o addr|sed -rn '/'$(ip -o route | sed -rn '/^default/s/.+dev ([a-z]+[0-9]).+/\1/p')'.+inet /s/.+ inet ([0-9\.]+).+/\1/p')   $(hostname)" >> /etc/hosts

