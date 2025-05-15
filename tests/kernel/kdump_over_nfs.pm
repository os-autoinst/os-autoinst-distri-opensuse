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

    select_console('root-console');

    if ($role eq 'nfs_client') {
        configure_service(test_type => 'function', yast_interface => 'cli');
        configure_kdump_with_nfs;
    }

    barrier_wait("KDUMP_PROVISIONED");

    if ($role eq 'nfs_client') {
        do_kdump;
    }

    barrier_wait("KDUMP_TRIGGERED");

    if ($role eq 'nfs_server') {
        only_check_kdump;
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
