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


sub nfs_run_io_tests {
    my @mounts = @_;
    my @flags = qw(direct dsync sync);

    foreach my $path (@mounts) {
        # Basis-Dateien kopieren
        assert_script_run("cp testfile md5sum.txt $path");

        # Verschiedene IO-Flags testen
        foreach my $flag (@flags) {
            assert_script_run("dd oflag=$flag if=testfile of=$path/testfile_oflag_$flag bs=1024 count=10240");
        }
        # Optional: Validierung der Kopie
        assert_script_run("md5sum -c md5sum.txt", die_on_fail => 1, run_args => {workdir => $path});
    }
}

sub mount_share {
    my ($server, $share, $local, $opts) = @_;
    return assert_script_run("mount -t nfs -o $opts $server:$share $local");
}

sub verify_nfs_support {
    my %args = @_;
    my $ver = $args{version} // 'V3';
    my $is_server = $args{is_server} // 0;
    my $softfail = $args{optional} // 0;

    if (script_run('test -f /proc/config.gz') != 0) {
        my $msg = "/proc/config.gz missing! Kernel config not exported.";
        if ($softfail) {
            record_soft_failure("NFS Support missing: $msg");
            return 0;
        }
        record_info("config.gz not found", $msg, result => 'fail');
        die $msg;
    }

    my $config_key = $is_server
      ? (($ver =~ /V4/) ? "CONFIG_NFSD_V4" : "CONFIG_NFSD")
      : "CONFIG_NFS_$ver";

    if (script_run("zgrep '$config_key=[my]' /proc/config.gz") != 0) {
        my $info = "Flag: $config_key\nVersion: $ver\nRole: " . ($is_server ? "Server" : "Client");

        if ($softfail) {
            record_soft_failure("NFS support misssing: $config_key missing");
            return 0;
        }

        record_info("NFS Supoport missing", $info, result => 'fail');
        die "FATAL: NFS support check failed for $config_key";
    }

    return 1;
}

sub run {
    select_serial_terminal();
    record_info("hostname", script_output("hostname"));
    my $server_node = get_var('SERVER_NODE', 'server-node00');

    zypper_call("in nfs-client");

    my $local_nfs3 = get_var('NFS_LOCAL_NFS3', '/home/localNFS3');
    my $local_nfs3_async = get_var('NFS_LOCAL_NFS3_ASYNC', '/home/localNFS3async');
    my $local_nfs4 = get_var('NFS_LOCAL_NFS4', '/home/localNFS4');
    my $local_nfs4_async = get_var('NFS_LOCAL_NFS4_ASYNC', '/home/localNFS4async');
    my $multipath = get_var('NFS_MULTIPATH', '0');

    my $softfail_nfs3 = get_var('NFS_SOFTFAIL_CONF_NFS3', 0);
    my $softfail_nfs4 = get_var('NFS_SOFTFAIL_CONF_NFS4', 0);

    barrier_wait("NFS_SERVER_ENABLED");
    record_info("showmount", script_output("showmount -e $server_node"));

    assert_script_run("dd if=/dev/zero of=testfile bs=1024 count=10240");
    assert_script_run("md5sum testfile > md5sum.txt");

    if (verify_nfs_support('V3', server => 0, softfail => $softfail_nfs3)) {
        record_info('INFO', 'Kernel has support for NFSv3');

        mount_share($server_node, "/nfs/shared_nfs3", $local_nfs3, "-o nfsvers=3,sync");
        mount_share($server_node, "/nfs/shared_nfs3_async", $local_nfs3_async, "-o nfsvers=3");

        nfs_run_io_tests($local_nfs3, $local_nfs3_async);
    }

    if (verify_nfs_support('V4', server => 0, optional => $softfail_nfs4)) {
        record_info('INFO', 'Kernel has support for NFSv4');

        mount_share($server_node, "/nfs/shared_nfs4", $local_nfs4, "-o nfsvers=4,sync");
        mount_share($server_node, "/nfs/shared_nfs4_async", $local_nfs4_async, "-o nfsvers=4");

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
