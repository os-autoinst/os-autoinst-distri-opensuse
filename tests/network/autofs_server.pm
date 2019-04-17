# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: It shares a dir via nfs for autofs testing, and another dir
#          for testing nfsidmap functionality.
#
# Maintainer: Antonio Caristia <acaristia@suse.com> (autofs)
# Maintainer: Timo Jyrinki <tjyrinki@suse.com> (nfsidmap)

use base 'consoletest';
use testapi;
use lockapi;
use utils qw(systemctl zypper_call);
use version_utils qw(is_opensuse);
use strict;
use warnings;

sub run {
    select_console "root-console";
    my $test_share_dir     = "/tmp/nfs/server";
    my $nfsidmap_share_dir = "/home/tux";
    if (is_opensuse) {
        zypper_call('modifyrepo -e 1');
        zypper_call('ref');
    }
    # autofs
    zypper_call('in nfs-kernel-server');
    assert_script_run "mkdir -p $test_share_dir";
    assert_script_run "echo It worked > $test_share_dir/file.txt";
    assert_script_run "echo $test_share_dir *(ro) >> /etc/exports";
    systemctl 'start nfs-server';
    validate_script_output("systemctl --no-pager status nfs-server", sub { m/Active:\s*active/ }, 180);

    # nfsidmap
    assert_script_run "echo N > /sys/module/nfsd/parameters/nfs4_disable_idmapping";
    zypper_call('in nfsidmap');
    systemctl 'restart nfs-idmapd';
    assert_script_run "nfsidmap -c";
    assert_script_run "useradd -m tux";
    assert_script_run "echo Hi tux > $nfsidmap_share_dir/tux.txt";
    assert_script_run "chown tux:users $nfsidmap_share_dir/tux.txt";
    assert_script_run "echo '/home/tux *(ro)' >> /etc/exports";

    # common
    assert_script_run "cat /etc/exports";
    systemctl 'restart nfs-server';
    barrier_wait 'AUTOFS_SUITE_READY';
    barrier_wait 'AUTOFS_FINISHED';
}

1;
