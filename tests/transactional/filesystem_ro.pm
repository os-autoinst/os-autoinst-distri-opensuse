# SUSE's openQA tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: btrfsprogs util-linux
# Summary: Check that root filesystem is read only
# Maintainer: Martin Kravec <mkravec@suse.com>
# Tags: https://fate.suse.com/321755

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal;

sub run {
    select_serial_terminal;

    die 'Should have failed' unless script_run('touch /should_fail');
    assert_script_run "touch /etc/should_succeed";
    assert_script_run "touch /var/log/should_succeed";

    assert_script_run 'btrfs property get / ro | grep "ro=true"';
    assert_script_run 'btrfs property get /var ro | grep "ro=false"';

    # Look for ro mount point in fstab
    assert_script_run "findmnt -s / -n -O ro";
    # Look for ro mount point in mounted filesystems
    assert_script_run "findmnt / -n -O ro";
}

1;
