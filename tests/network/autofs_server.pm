# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: nfs-kernel-server nfs-client
# Summary: It shares a dir via nfs for autofs testing, and another dir
#          for testing nfsidmap functionality.
# - If opensuse, enables repository 1 (zypper modifyrepo -e 1) and refresh
# - Install package nfs-kernel-server
# - Create directory /tmp/nfs/server
# - Create file "file.txt" inside above directory with contents "It worked"
# - Add "/tmp/nfs/server *(ro)" to end of /etc/exports
# - Start nfs-server
# - Run "systemctl --no-pager status nfs-server", check output for
# "Active:\s*active"
# - Run "echo N > /sys/module/nfsd/parameters/nfs4_disable_idmapping"
# - Install nfsidmap
# - Restart service nfs-idmapd
# - Clear nfsidmap keyring "nfsidmap -c || true"
# - Add user tux "useradd -m tux"
# - Write "Hi tux" to /home/tux/tux.txt
# - Run "chown tux:users" to /home/tux/tux.txt
# - Append "/home/tux *(ro)" to /etc/exports
# - Run "cat /etc/exports"
# - Restart nfs-server
# - Call AUTOFS_SUITE_READY
# - Call AUTOFS_FINISHED
# Maintainer: Antonio Caristia <acaristia@suse.com> (autofs)
# Maintainer: Timo Jyrinki <tjyrinki@suse.com> (nfsidmap)

use base 'consoletest';
use testapi;
use lockapi;
use utils qw(systemctl zypper_call);
use version_utils 'is_opensuse';
use strict;
use warnings;

sub run {
    # MM tests autofs requires barrier_create
    barrier_create('AUTOFS_SUITE_READY', 2);
    barrier_create('AUTOFS_FINISHED', 2);
    mutex_create 'barrier_setup_done';

    select_console "root-console";
    my $test_share_dir = "/tmp/nfs/server";
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
    is_opensuse ? zypper_call('in libnfsidmap1') : zypper_call('in nfsidmap');
    systemctl 'restart nfs-idmapd';
    assert_script_run "nfsidmap -c || true";
    assert_script_run "useradd -m tux";
    assert_script_run "chmod -R 755 $nfsidmap_share_dir";
    assert_script_run "echo Hi tux > $nfsidmap_share_dir/tux.txt";
    assert_script_run "chown tux:users $nfsidmap_share_dir/tux.txt";
    assert_script_run "echo '/home/tux *(ro)' >> /etc/exports";

    # common
    assert_script_run "cat /etc/exports";
    systemctl 'restart nfs-server';
    # check for bsc#1215649
    # https://progress.opensuse.org/issues/136004
    if (script_output("systemctl --no-pager status nfs-server") =~ m/status=1\/FAILURE/) {
        record_soft_failure 'bsc#1215649';
        systemctl 'stop nfs-server';
        systemctl 'start nfs-server';
    }
    barrier_wait 'AUTOFS_SUITE_READY';
    barrier_wait 'AUTOFS_FINISHED';
}
1;
