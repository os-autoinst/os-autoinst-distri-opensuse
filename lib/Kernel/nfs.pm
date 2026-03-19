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
