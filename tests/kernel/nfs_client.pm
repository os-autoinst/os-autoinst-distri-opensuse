# SUSE's openQA tests
#
# Copyright 2023-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: NFS Client
#    This module provisions the NFS client and then runs some basic
#    sanity tests. Detailed description of the tests can be found in:
#    tests/kernel/nfs_server.pm

# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal "select_serial_terminal";
use lockapi;
use utils;
use Kernel::nfs;
use package_utils "install_package";

sub run {
    select_serial_terminal();
    record_info("hostname", script_output("hostname"));
    my $server_node = get_var('SERVER_NODE', 'server-node00');

    install_package('nfs-client', trup_continue => 1);

    my $local_nfs3 = get_var('NFS_LOCAL_NFS3', '/home/localNFS3');
    my $local_nfs3_async = get_var('NFS_LOCAL_NFS3_ASYNC', '/home/localNFS3async');
    my $local_nfs4 = get_var('NFS_LOCAL_NFS4', '/home/localNFS4');
    my $local_nfs4_async = get_var('NFS_LOCAL_NFS4_ASYNC', '/home/localNFS4async');
    my $multipath = get_var('NFS_MULTIPATH', '0');

    my $nfs3 = verify_nfs_support(version => 'V3', is_server => 0);
    my $nfs4 = verify_nfs_support(version => 'V4', is_server => 0);

    barrier_wait("NFS_SERVER_ENABLED");
    record_info("showmount", script_output("showmount -e $server_node"));

    assert_script_run("dd if=/dev/zero of=testfile bs=1024 count=10240");
    assert_script_run("md5sum testfile > md5sum.txt");

    if ($nfs3) {
        record_info('INFO', 'Kernel has support for NFSv3');

        mount_share($server_node, "/nfs/shared_nfs3", $local_nfs3, "nfsvers=3,sync");
        mount_share($server_node, "/nfs/shared_nfs3_async", $local_nfs3_async, "nfsvers=3");

        nfs_run_io_tests($local_nfs3, $local_nfs3_async);
    }

    if ($nfs4) {
        record_info('INFO', 'Kernel has support for NFSv4');

        mount_share($server_node, "/nfs/shared_nfs4", $local_nfs4, "nfsvers=4,sync");
        mount_share($server_node, "/nfs/shared_nfs4_async", $local_nfs4_async, "nfsvers=4");

        nfs_run_io_tests($local_nfs4, $local_nfs4_async);
    }

    barrier_wait("NFS_SERVER_CHECK");
}



sub test_flags {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    $self->destroy_test_barriers();
    select_serial_terminal;
}

1;
