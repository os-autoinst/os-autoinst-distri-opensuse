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

=head2 nfs_run_io_tests

    nfs_run_io_tests(@mounts)

Runs IO tests (sync, dsync, direct) on a list of mount points and verifies data integrity.
Requires a file named 'testfile' in the current working directory.

Parameters:
- C<mounts>: List of paths (mount points) to test.

=cut

sub nfs_run_io_tests {
    my @mounts = @_;
    my @flags = qw(sync dsync direct);

    foreach my $path (@mounts) {
        next if script_run("test -d $path && test -w $path") != 0;

        foreach my $flag (@flags) {
            my $out_file = "$path/testfile_oflag_$flag";
            my $ret = script_run("dd if=testfile of=$out_file bs=1M count=10 oflag=$flag");

            if ($ret != 0) {
                if ($flag eq 'direct') {
                    record_info("NFS O_DIRECT failed on $path");
                } else {
                    die "NFS IO failed for $flag on $path (Exit: $ret)";
                }
                next;
            }
            assert_script_run("md5sum testfile | sed 's|testfile|$out_file|' | md5sum -c");
        }

        assert_script_run("cp testfile md5sum.txt $path/");
        assert_script_run("cd $path && md5sum testfile_oflag_* >> md5sum.txt && cd -");
        script_run("sync $path");
    }
}



sub run {
    select_serial_terminal();
    record_info("hostname", script_output("hostname"));

    my $server_node = get_var('SERVER_NODE', 'server-node00');
    my @nfs_versions = qw(V3 V4);
    my @active_mounts;

    install_package('nfs-client', trup_continue => 1);

    barrier_wait("NFS_SERVER_ENABLED");
    record_info("showmount", script_output("showmount -e $server_node"));

    assert_script_run("dd if=/dev/zero of=testfile bs=1024 count=10240");
    assert_script_run("md5sum testfile > md5sum.txt");

    foreach my $ver (@nfs_versions) {
        if (verify_nfs_support(version => $ver, is_server => 0)) {
            record_info('INFO', "Kernel and Config support $ver client");

            my $v_num = $ver =~ s/V//gr;

            # Match server's path construction exactly
            my $remote_base = get_var("NFS_SHARE_$ver", "/nfs/shared_$ver");
            my $local_sync = get_var("NFS_LOCAL_$ver", "/home/local$ver");
            my $local_async = $local_sync . "async";

            mount_share($server_node, $remote_base, $local_sync, "nfsvers=$v_num,sync");
            mount_share($server_node, "${remote_base}_async", $local_async, "nfsvers=$v_num");

            nfs_run_io_tests($local_sync, $local_async);
            push @active_mounts, ($local_sync, $local_async);
        }
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
