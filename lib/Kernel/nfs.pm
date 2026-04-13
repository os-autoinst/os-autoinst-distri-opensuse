# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Kernel::nfs;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;

our @EXPORT = qw(
  verify_nfs_support
  nfs_run_io_tests
  mount_share
  create_mount_and_export
  nfs_verify_checksums
);


=head1 SYNOPSIS

Utils and helper for working with nfs tests.

=cut

=head2 verify_nfs_support
  
  verify_nfs_support([version => 'V3'], [is_server => 0]);

Checks kernel support for various NFS versions by inspecting /proc/config.gz.
Returns 1 if support is found.

Parameters:
- C<version>: NFS Version (e.g. 'V3', 'V4', 'V4.1', 'V4.2'). Default: 'V3'.
- C<is_server>: If true, checks for NFSD support. Default: 0 (client).
=cut

sub verify_nfs_support {
    my %args = @_;
    my $ver = uc($args{version}) // 'V3';
    my $is_server = $args{is_server} // 0;

    if (script_run('test -f /proc/config.gz') != 0) {
        die "/proc/config.gz missing!";
    }

    my $config_key;
    if ($is_server) {
        $config_key = ($ver =~ /V4/) ? "CONFIG_NFSD_V4" : "CONFIG_NFSD";
    } else {
        my $suffix = $ver;
        $suffix =~ s/\./_/g;
        $config_key = "CONFIG_NFS_$suffix";
    }

    if (script_run("zgrep -q '$config_key=[my]' /proc/config.gz") != 0) {
        die "FATAL: NFS support check failed for $config_key";
    }

    return 1;
}

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

=head2 mount_share

    mount_share($server, $share, $local, $opts);

Creates a local directory and mounts an NFS share with the given options.
Uses assert_script_run to ensure the mount command succeeds.

Parameters:
- C<server>: Hostname or IP of the NFS server.
- C<share>: Remote path exported by the server.
- C<local>: Local mount point (will be created with mkdir -p).
- C<opts>: Mount options string (e.g. 'nfsvers=4.2,nosuid').

=cut

sub mount_share {
    my ($server, $share, $local, $opts) = @_;
    script_run("mkdir -p $local");
    return assert_script_run("mount -t nfs -o $opts $server:$share $local");
}


=head2 create_mount_and_export

    create_mount_and_export($mountpoint, $cl, $permissions);

Creates a local directory with open permissions (777) and adds a corresponding 
entry to F</etc/exports> to make it available for NFS clients.

Parameters:
- C<mountpoint>: Local path to be created and exported.
- C<cl>: Client specification (e.g. '*' or a specific network/IP).
- C<permissions>: Export options (e.g. 'rw,sync,no_root_squash').

=cut

sub create_mount_and_export {
    my ($mountpoint, $cl, $permissions) = @_;

    assert_script_run "mkdir -p $mountpoint";
    assert_script_run "chmod 777 $mountpoint";
    assert_script_run "echo $mountpoint $cl\\($permissions\\) >> /etc/exports";
}

=head2 nfs_verify_checksums

    nfs_verify_checksums($path);

Verifies NFS file integrity for sync, dsync, and direct IO flags at the given path.
Logs the directory content and checks against the 'md5sum.txt' within that directory.

Parameters:
- C<path>: The mount point or subdirectory to verify.

=cut

sub nfs_verify_checksums {
    my ($path) = @_;
    my @flags = qw(direct dsync sync);

    # Verzeichnisinhalt für das openQA-Log erfassen
    my $ls_output = script_output("ls -la $path");
    record_info("Verify: " . (split('/', $path))[-1], "Path: $path\n\n$ls_output");

    # Basis-Check: Existiert die md5sum.txt überhaupt?
    assert_script_run("test -f $path/md5sum.txt");

    # Validierung gegen die md5sum.txt
    assert_script_run("cd $path && md5sum -c md5sum.txt");

    foreach my $flag (@flags) {
        my $file = "testfile_oflag_$flag";

        # -w stellt sicher, dass wir exakt den Dateinamen treffen
        my $expected = script_output("grep -w '$file' $path/md5sum.txt | cut -d ' ' -f1");
        my $actual = script_output("md5sum $path/$file | cut -d ' ' -f1");

        if ($expected ne $actual) {
            die "Checksum mismatch in $path for $file!\nExpected: $expected\nActual:   $actual";
        }
    }
}

1;
