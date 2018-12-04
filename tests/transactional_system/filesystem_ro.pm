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
use version_utils qw(is_caasp is_leap is_tumbleweed);

sub run {
    select_console 'root-console' if (check_var('DISTRI', 'opensuse'));
    assert_script_run "! touch /should_fail";
    assert_script_run "touch /etc/should_succeed";
    assert_script_run "touch /var/log/should_succeed";

    assert_script_run 'btrfs property get / ro | grep "ro=true"';

    if (is_caasp('4.0+') || is_leap('15.0+') || is_tumbleweed) {
        assert_script_run 'btrfs property get /var ro | grep "ro=false"';
    }
    else {
        assert_script_run 'btrfs property get /var/log ro | grep "ro=false"';
    }

    # Look for ro mount point in fstab
    assert_script_run "findmnt -s / -n -O ro";
    # Look for ro mount point in mounted filesystems
    assert_script_run "findmnt / -n -O ro";
}

1;
