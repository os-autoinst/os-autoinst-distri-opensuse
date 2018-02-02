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
# Tags: https://fate.suse.com/321755

use base "opensusebasetest";
use strict;
use testapi;
use version_utils 'is_caasp';

sub run {
    assert_script_run "! touch /should_fail";
    assert_script_run "touch /etc/should_succeed";
    assert_script_run "touch /var/log/should_succeed";

    assert_script_run 'btrfs property get / ro | grep "ro=true"';

    if (is_caasp '4.0+') {
        assert_script_run 'btrfs property get /var ro | grep "ro=false"';
        assert_script_run 'lsattr -ld /var | grep No_COW';
    }
    else {
        assert_script_run 'btrfs property get /var/log ro | grep "ro=false"';
    }

    if (is_caasp 'caasp') {
        assert_script_run "grep '/ btrfs ro' /etc/fstab";
        assert_script_run "mount | grep 'on / type btrfs (ro,'";
    }
    else {
        record_soft_failure 'bsc#1079000 - Missing readonly option in fstab';
    }
}

1;
# vim: set sw=4 et:
