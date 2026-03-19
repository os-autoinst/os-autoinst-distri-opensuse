# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Kernel::usb;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;

our @EXPORT = qw(
  verifiy_nfs_support
  nfs_run_io_tests
  mount_share
);

=head1 SYNOPSIS

Utils and helper for working with nfs tests.

=cut

=head2 verify_nfs_support
  
  verify_nfs_support([version => 'V3'], [is_server => 0], [optional => 0]);

Checks kernel support for various NFS versions by inspecting /proc/config.gz.
Returns 1 if support is found, 0 if missing (only when 'optional' is set).

Parameters:
- C<version>: NFS Version (e.g. 'V3', 'V4', 'V4.1', 'V4.2'). Default: 'V3'.
- C<is_server>: If true, checks for NFSD support. Default: 0 (client).
- C<optional>: If true, records a soft failure instead of die() if support is missing.
=cut

sub verify_nfs_support {
    my %args = @_;
    my $ver = uc($args{version}) // 'V3';
    my $is_server = $args{is_server} // 0;
    my $softfail = $args{optional} // 0;

    if (script_run('test -f /proc/config.gz') != 0) {
        return 0 if $softfail;
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
        if ($softfail) {
            record_soft_failure("NFS support missing: $config_key");
            return 0;
        }
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
        if (script_run("test -d $path && test -w $path") != 0) {
            record_info("Skip Path", "Path $path not accessible or writable", result => 'fail');
            next;
        }

        foreach my $flag (@flags) {
            my $out_file = "$path/testfile_oflag_$flag";
            my $ret = script_run("dd if=testfile of=$out_file bs=1M count=10 oflag=$flag");

            if ($ret != 0) {
                if ($flag eq 'direct') {
                    record_soft_failure("NFS O_DIRECT failed on $path");
                } else {
                    die "NFS IO failed for $flag on $path (Exit: $ret)";
                }
                next;
            }

            assert_script_run("md5sum testfile | sed 's|testfile|$out_file|' | md5sum -c");
        }
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

1;
