# SUSE's openQA tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Can add SocketCAN kernel driver without problems
# Maintainer: mkravec <mkravec@suse.com>

use base "opensusebasetest";
use testapi;

# https://fate.suse.com/317131
sub run {
    assert_script_run "modprobe peak_pci";
    assert_script_run "lsmod | grep ^peak_pci";
}

1;
