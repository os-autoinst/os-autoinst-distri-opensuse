# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check that root filesystem is read only
# Maintainer: Martin Kravec <mkravec@suse.com>

use base "opensusebasetest";
use strict;
use testapi;

sub run() {
    assert_script_run "! touch /should_fail";

    assert_script_run "touch /var/log/should_succeed";
    assert_script_run "rm /var/log/should_succeed";

    assert_script_run 'btrfs property get / ro | grep "ro=true"';
    assert_script_run 'btrfs property get /var/log ro | grep "ro=false"';

    assert_script_run "grep '/ btrfs ro' /etc/fstab";
    assert_script_run "mount | grep 'on / type btrfs (ro,'";
}

sub test_flags() {
    return {important => 1};
}

1;
# vim: set sw=4 et:
