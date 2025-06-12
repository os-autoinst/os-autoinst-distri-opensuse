# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Configure and run kdump over NFS
# Maintainer: QE Kernel <kernel-qa@suse.de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils;
use kdump_utils;
use lockapi;

sub run {
    my ($self) = @_;
    my $role = get_required_var('ROLE');
    my $local_nfs3 = get_var('NFS_LOCAL_NFS3', '/home/localNFS3');

    select_console('root-console');

    if ($role eq 'nfs_client') {
        set_kdump_config('KDUMP_SAVEDIR', $local_nfs3);
    }

    barrier_wait("KDUMP_PROVISIONED");

    if ($role eq 'nfs_client') {
        record_info('CLINET');
    }

    barrier_wait("KDUMP_TRIGGERED");

    if ($role eq 'nfs_server') {
        record_info('SERVER');
    }


}

sub post_fail_hook {
    my ($self) = @_;

    script_run 'ls -lah /boot/';
    script_run 'tar -cvJf /tmp/crash_saved.tar.xz -C /var/crash .';
    upload_logs '/tmp/crash_saved.tar.xz';

    $self->SUPER::post_fail_hook;
}

1;
