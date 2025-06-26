# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Configure and run kdump over NFS.
# The test is configuring - on the nfs client side - the kdump with
# KDUMP_SAVEDIR set to NFS share. Then the actual crash is triggered,
# still on the NFS client side and once the reboot happens, the nfs share,
# set as the target in the KDUMP_SAVEDIR, is mounted and the crash files
# are checked
#
# Maintainer: QE Kernel <kernel-qa@suse.de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils;
use kdump_utils;
use lockapi;
use power_action_utils 'power_action';

sub run {
    my ($self) = @_;
    my $role = get_required_var('ROLE');
    my $nfs_server = get_var('NFS_SERVER', 'server-node00');

    get_required_var('KDUMP_SAVEDIR');

    select_console('root-console');

    #Specific wicked workaround for SLE15 - allow connection from all hosts
    if ($role eq 'nfs_server') {
        assert_script_run("echo '/nfs/shared_nfs3 10.0.2.0/24(rw,sync,no_subtree_check,no_root_squash)' > /etc/exports");
        assert_script_run("exportfs -ra");
    }

    barrier_wait('KDUMP_WICKED_TEMP');

    if ($role eq 'nfs_client') {
        assert_script_run("mkdir -p /var/crash");
        assert_script_run("echo \"$nfs_server:/nfs/shared_nfs3 /var/crash nfs nfsvers=3,sync,nofail,x-systemd.automount 0 0\" >> /etc/fstab");
        assert_script_run("mount -a");

        configure_service(test_type => 'function', yast_interface => 'cli');
        check_function(test_type => 'function');
    }
    barrier_wait("KDUMP_MULTIMACHINE");
}

sub post_fail_hook {
    my ($self) = @_;

    script_run 'ls -lah /boot/';
    script_run 'tar -cvJf /tmp/crash_saved.tar.xz -C /var/crash .';
    upload_logs '/tmp/crash_saved.tar.xz';

    $self->SUPER::post_fail_hook;
}

1;
