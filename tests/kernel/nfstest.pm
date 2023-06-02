# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: Test NFS under specific load/stress using stress-ng
# Summary: NFStest
#          https://linux-nfs.org/wiki/index.php/NFStest
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base "opensusebasetest";
use testapi;
use serial_terminal "select_serial_terminal";
use utils;
use lockapi;
use Utils::Logging "export_logs_basic";
use registration "is_phub_ready";

sub run {
    select_serial_terminal();

    #Below is just a temp ways of getting the test done
    assert_script_run("SUSEConnect -p PackageHub/15.5/x86_64");
    # Package 'stress-ng' requires PackageHub is available
    return unless is_phub_ready();
    zypper_call("in stress-ng");

    if (get_var("ROLE") eq "nfs_client") {
        #TODO: consider other stress-ng options
        background_script_run("stress-ng --netdev 6 -t 3m --times -vvv");
	#just make sure stress-ng can kick off
	sleep(5);

        my $local_nfs3 = "/home/localNFS3";
        my $local_nfs4 = "/home/localNFS4";
        my $local_nfs3_async = "/home/localNFS3async";
        my $local_nfs4_async = "/home/localNFS4async";

        #run basic checks while client is under stress - add a file to each folder and check
	#for the checksum proper tests should come in the next modules
        assert_script_run("dd if=/dev/zero of=testfile bs=1024 count=102400");
        assert_script_run("md5sum testfile > md5sum.txt");
        assert_script_run("cp testfile md5sum.txt $local_nfs3");
        assert_script_run("cp testfile md5sum.txt $local_nfs4");
        assert_script_run("cp testfile md5sum.txt $local_nfs3_async");
        assert_script_run("cp testfile md5sum.txt $local_nfs4_async");

        barrier_wait("NFS_CLIENT_ACTIONS");
	barrier_wait("NFS_SERVER_ACTIONS");
    } else {
        barrier_wait("NFS_CLIENT_ACTIONS");
	#just for fun stress the nfs server too
        background_script_run("stress-ng --netdev 6 -t 3m --times -vvv");
        #just make sure stress-ng can kick off
        sleep(5);

        my $nfs_mount_nfs3 = "/nfs/shared_nfs3";
        my $nfs_mount_nfs4 = "/nfs/shared_nfs4";
        my $nfs_mount_nfs3_async = "/nfs/shared_nfs3_async";
        my $nfs_mount_nfs4_async = "/nfs/shared_nfs4_async";

        assert_script_run("cd $nfs_mount_nfs3");
        assert_script_run("md5sum -c md5sum.txt");
        record_info("NFS3 checksum", script_output("md5sum -c md5sum.txt"));

        assert_script_run("cd $nfs_mount_nfs4");
        assert_script_run("md5sum -c md5sum.txt");
        record_info("NFS4 checksum", script_output("md5sum -c md5sum.txt"));

        assert_script_run("cd $nfs_mount_nfs3_async");
        assert_script_run("md5sum -c md5sum.txt");
        record_info("NFS3 async checksum", script_output("md5sum -c md5sum.txt"));

        assert_script_run("cd $nfs_mount_nfs4_async");
        assert_script_run("md5sum -c md5sum.txt");
        record_info("NFS4 async checksum", script_output("md5sum -c md5sum.txt"));

        record_info("NFS stat for server", script_output("nfsstat -s"));
        barrier_wait("NFS_SERVER_ACTIONS");
    }

}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    select_serial_terminal;
    export_logs_basic;
    script_run("rpm -qi kernel-default > /tmp/kernel_info");
    upload_logs("/tmp/kernel_info");

}

1;
