# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: NFS Client
#    This module provisions the NFS client and then runs some basic
#    sanity tests
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base "opensusebasetest";
use testapi;
use serial_terminal "select_serial_terminal";
use lockapi;
use utils;

sub run {
    select_serial_terminal();

    my $local_nfs3 = "/home/localNFS3";
    my $local_nfs4 = "/home/localNFS4";
    my $local_nfs3_async = "/home/localNFS3async";
    my $local_nfs4_async = "/home/localNFS4async";

    mutex_wait('NFS_BARRIERS_CREATED');
    barrier_wait("NFS_SERVER_ENABLED");

    record_info("showmount", script_output("showmount -e server-node00"));

    assert_script_run("mkdir $local_nfs3 $local_nfs4 $local_nfs3_async $local_nfs4_async");
    assert_script_run("mount -t nfs -o nfsvers=3 server-node00:/nfs/shared_nfs3 $local_nfs3");
    assert_script_run("mount -t nfs -o nfsvers=4 server-node00:/nfs/shared_nfs4 $local_nfs4");
    assert_script_run("mount -t nfs -o nfsvers=3 server-node00:/nfs/shared_nfs3_async $local_nfs3_async");
    assert_script_run("mount -t nfs -o nfsvers=4 server-node00:/nfs/shared_nfs4_async $local_nfs4_async");

    barrier_wait("NFS_CLIENT_ENABLED");

    #run basic checks - add a file to each folder and check for the checksum
    #proper tests should come in the next modules
    assert_script_run("dd if=/dev/zero of=testfile bs=1024 count=10240");
    assert_script_run("md5sum testfile > md5sum.txt");
    assert_script_run("cp testfile md5sum.txt $local_nfs3");
    assert_script_run("cp testfile md5sum.txt $local_nfs4");
    assert_script_run("cp testfile md5sum.txt $local_nfs3_async");
    assert_script_run("cp testfile md5sum.txt $local_nfs4_async");

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
