# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: It shares a dir via nfs
# Maintainer: Antonio Caristia <acaristia@suse.com>

use base 'consoletest';
use testapi;
use lockapi;
use utils qw(systemctl zypper_call);
use version_utils qw(is_opensuse);
use strict;
use warnings;

sub run {
    select_console "root-console";
    my $test_share_dir = "/tmp/nfs/server";
    if (is_opensuse) {
        zypper_call('modifyrepo -e 1');
        zypper_call('ref');
    }
    zypper_call('in nfs-kernel-server');
    assert_script_run "mkdir -p $test_share_dir";
    assert_script_run "echo It worked > $test_share_dir/file.txt";
    assert_script_run "echo $test_share_dir *(ro) >> /etc/exports";
    assert_script_run "cat /etc/exports";
    systemctl 'start nfs-server';
    validate_script_output("systemctl --no-pager status nfs-server", sub { m/Active:\s*active/ }, 180);
    barrier_wait 'AUTOFS_SUITE_READY';
    barrier_wait 'AUTOFS_FINISHED';
}

1;
