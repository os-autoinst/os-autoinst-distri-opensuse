# SUSE's openQA tests
#
# Copyright 2015-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-nfs-server nfs-kernel-server nfs-client
# Summary: Add new yast2_nfs_server test
#    This tests "yast2 nfs-server" by creating an NFS share,
#    writing a file to it and validating that the file is accessible
#    after mounting.
#    It can also be used as a server in an "/ on NFS" test scenario.
#    In this case, NFSSERVER has to be 1, the server is accessible as
#    10.0.2.101 and it provides a mutex "nfs_ready".
#    * We used YaST for configuring and creating this server
#    * We also create some testing files for the client
#    * The NFSv3 version is mounted and checked
# Maintainer: Fabian Vogt <fvogt@suse.com>

use strict;
use warnings;

use base "y2_module_consoletest";
use utils qw(clear_console zypper_call systemctl);
use version_utils;
use testapi;
use lockapi;
use mmapi;
use mm_network;
use nfs_common;
use version_utils 'is_sle';

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    if (get_var('NFSSERVER')) {
        server_configure_network($self);
    }

    install_service;

    # From now we need needles
    select_console 'root-console';

    config_service($rw, $ro);

    # From now we can use serial terminal
    $self->select_serial_terminal;

    start_service($rw, $ro);

    mutex_create('nfs_ready');

    if (get_var('NFSSERVER')) {
        assert_script_run "mount 10.0.2.101:${rw} /mnt";
    }
    else {
        assert_script_run "mount 10.0.2.15:${rw} /mnt";
    }

    # Timeout of 95 seconds to account for the NFS server grace period
    validate_script_output("cat /mnt/file.txt", sub { m,success, }, 95);

    # Check NFS version
    if ((is_sle('=12-sp1') || is_sle('=12-sp2')) && script_run 'nfsstat -m') {
        record_soft_failure 'bsc#1140731';
    }
    else {
        validate_script_output "nfsstat -m", sub { m/vers=3/ };
    }

    check_service($rw, $ro);

    assert_script_run 'umount /mnt';

    wait_for_children;
}

1;

