# SUSE's openQA tests
#
# Copyright 2023-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: NFS Client
#    This module provisions the NFS client and then runs some basic
#    sanity tests. Detailed description of the tests can be found in:
#    tests/kernel/nfs_server.pm

# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base "opensusebasetest";
use testapi;
use serial_terminal "select_serial_terminal";
use lockapi;
use utils;
use Utils::Backends 'is_ipmi';
use Kernel::net_tests 'get_ipv4_addresses';

sub copy_file {
    my ($flag, $nfs_mount, $file) = @_;
    assert_script_run("dd oflag=$flag if=testfile of=$nfs_mount/$file bs=1024 count=10240");
}

sub run {
    select_serial_terminal();
    record_info("hostname", script_output("hostname"));
    my $server_node = get_var('SERVER_NODE');
    # Baremetal/ipmi multimachine jobs commonly provide peer IPs via IBTEST_IP*
    # and not DNS-resolvable hostnames.
    if (is_ipmi) {
        my $ip1 = get_var('IBTEST_IP1');
        my $ip2 = get_var('IBTEST_IP2');
        my $detected_ipv4 = get_ipv4_addresses();
        my @local_ips = map { @$_ } values %$detected_ipv4;

        if (grep { $_ eq $ip1 } @local_ips) {
            $server_node = $ip2;
        } elsif (grep { $_ eq $ip2 } @local_ips) {
            $server_node = $ip1;
        } else {
            @local_ips = sort @local_ips;
            record_info("IP mapping", "local_ips=@local_ips ib1=$ip1 ib2=$ip2", result => 'fail');
            die "Unable to map server node: local host does not have IBTEST_IP1 or IBTEST_IP2";
        }
        @local_ips = sort @local_ips;
        record_info("IP mapping", "local_ips=@local_ips peer=$server_node");
    } else {
        $server_node //= 'server-node00';
    }

    zypper_call("in nfs-client");

    my $local_nfs3 = get_var('NFS_LOCAL_NFS3', '/home/localNFS3');
    my $local_nfs3_async = get_var('NFS_LOCAL_NFS3_ASYNC', '/home/localNFS3async');
    my $local_nfs4 = get_var('NFS_LOCAL_NFS4', '/home/localNFS4');
    my $local_nfs4_async = get_var('NFS_LOCAL_NFS4_ASYNC', '/home/localNFS4async');
    my $multipath = get_var('NFS_MULTIPATH', '0');

    # check kernel config options and set the variables
    my $kernel_nfs3 = 0;
    my $kernel_nfs4 = 0;
    my $kernel_nfs4_1 = 0;
    my $kernel_nfs4_2 = 0;
    my $kernel_nfsd_v3 = 0;
    my $kernel_nfsd_v4 = 0;

    $kernel_nfs3 = 1 unless script_run('zgrep "CONFIG_NFS_V3=[my]" /proc/config.gz');
    $kernel_nfs4 = 1 unless script_run('zgrep "CONFIG_NFS_V4=[my]" /proc/config.gz');
    $kernel_nfs4_1 = 1 unless script_run('zgrep "CONFIG_NFS_V4_1=[my]" /proc/config.gz');
    $kernel_nfs4_2 = 1 unless script_run('zgrep "CONFIG_NFS_V4_2=[my]" /proc/config.gz');
    $kernel_nfsd_v3 = 1 unless script_run('zgrep "CONFIG_NFSD=[my]" /proc/config.gz');
    $kernel_nfsd_v4 = 1 unless script_run('zgrep "CONFIG_NFSD_V4=[my]" /proc/config.gz');

    barrier_wait("NFS_SERVER_ENABLED");
    assert_script_run("ping -c3 $server_node");
    record_info("ip a", script_output("ip a", proceed_on_failure => 1));
    record_info("RPC ping", script_output("rpcinfo -t $server_node portmapper", proceed_on_failure => 1));
    my $mountd_ready = script_retry("rpcinfo -t $server_node mountd", retry => 12, delay => 5, timeout => 30);
    die "mountd not reachable on $server_node" if $mountd_ready != 0;
    record_info("debug", "Sleeping before showmount for manual SSH inspection");
    my $showmount_ok = script_retry("showmount -e $server_node", retry => 12, delay => 10, timeout => 30);
    die "showmount failed for $server_node" if $showmount_ok != 0;
    record_info("showmount", script_output("showmount -e $server_node", proceed_on_failure => 1));

    if ($kernel_nfs3 == 1) {
        record_info('INFO', 'Kernel has support for NFSv3');
        assert_script_run("mkdir $local_nfs3 $local_nfs3_async");
        assert_script_run("mount -t nfs -o nfsvers=3,sync $server_node:/nfs/shared_nfs3 $local_nfs3");
        assert_script_run("mount -t nfs -o nfsvers=3 $server_node:/nfs/shared_nfs3_async $local_nfs3_async");
    } else {
        record_info('INFO', 'Kernel has no support for NFSv3, skipping NFSv3 tests');
    }

    if ($kernel_nfs4 == 1) {
        record_info('INFO', 'Kernel has support for NFSv4');
        assert_script_run("mkdir $local_nfs4 $local_nfs4_async");
        assert_script_run("mount -t nfs -o nfsvers=4,sync $server_node:/nfs/shared_nfs4 $local_nfs4");
        assert_script_run("mount -t nfs -o nfsvers=4 $server_node:/nfs/shared_nfs4_async $local_nfs4_async");
    } else {
        record_info('INFO', 'Kernel has no support for NFSv4, skipping NFSv4tests');
    }

    barrier_wait("NFS_CLIENT_ENABLED");

    #run basic checks - add a file to each folder and check for the checksum
    #proper tests should come in the next modules
    assert_script_run("dd if=/dev/zero of=testfile bs=1024 count=10240");
    assert_script_run("md5sum testfile > md5sum.txt");

    if ($kernel_nfs3 == 1) {
        assert_script_run("cp testfile md5sum.txt $local_nfs3");
        assert_script_run("cp testfile md5sum.txt $local_nfs3_async");

        copy_file('direct', $local_nfs3, 'testfile_oflag_direct');
        copy_file('dsync', $local_nfs3, 'testfile_oflag_dsync');
        copy_file('sync', $local_nfs3, 'testfile_oflag_sync');

        copy_file('direct', $local_nfs3_async, 'testfile_oflag_direct');
        copy_file('dsync', $local_nfs3_async, 'testfile_oflag_dsync');
        copy_file('sync', $local_nfs3_async, 'testfile_oflag_sync');
    }
    if ($kernel_nfs4 == 1) {
        assert_script_run("cp testfile md5sum.txt $local_nfs4");
        assert_script_run("cp testfile md5sum.txt $local_nfs4_async");

        copy_file('direct', $local_nfs4, 'testfile_oflag_direct');
        copy_file('dsync', $local_nfs4, 'testfile_oflag_dsync');
        copy_file('sync', $local_nfs4, 'testfile_oflag_sync');

        copy_file('direct', $local_nfs4_async, 'testfile_oflag_direct');
        copy_file('dsync', $local_nfs4_async, 'testfile_oflag_dsync');
        copy_file('sync', $local_nfs4_async, 'testfile_oflag_sync');
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
