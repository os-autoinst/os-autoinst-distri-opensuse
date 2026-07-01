# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Kernel::nfs;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;

our @EXPORT = qw(
  create_export
  compare_checksums
);

=head1 SYNOPSIS

Utils and helpers for nfs testing

=cut

=head2 create_export

  create_export();

Create an NFS share and export it with specified settings:
- C<path>: Filesystem path to export
- C<cl>: client IP/hostname to create the share for
- C<options>: options to record in /etc/exports

=cut 
sub create_export {
    my ($path, $cl, $options) = @_;

    assert_script_run "mkdir -p $path";
    assert_script_run "chmod 777 $path";
    assert_script_run "echo $path $cl\\($options\\) >> /etc/exports";
}


=head2 compare_checksums

  compare_checksums();

Compare the checksum of a file to the one recorded in md5sum.txt :

- C<file>: the file to check the checksum for
=cut
sub compare_checksums {
    my ($file) = @_;

    assert_script_run("md5sum $file > new_md5sum.txt");
    record_info("$file: checksum", script_output("cat new_md5sum.txt"));

    my $md5 = script_output("cut -d ' ' -f1 md5sum.txt");
    my $new_md5 = script_output("cut -d ' ' -f1 new_md5sum.txt");

    record_info("Checksums md5 $md5 newMd5: $new_md5");

    die "checksums differ $md5 : $new_md5" unless ($md5 eq $new_md5);
}


1;
