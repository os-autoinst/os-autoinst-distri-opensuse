# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Library to verify image data integrity by comparing SHA256 checksums.
# Maintainer: Joaquín Rivera <jeriveramoya@suse.com>

package data_integrity_utils;

use base Exporter;
use Exporter;
use strict;
use testapi;
use File::Basename;
use Digest::file 'digest_file_hex';

our @EXPORT = 'verify_checksum';

=head2 verify_checksum
Verify image data integrity by comparing SHA256 checksums
=cut
sub verify_checksum {
    my ($dir_path) = shift;    # for backends other than qemu, image directory path needs to be set

    # Since this operation can take up some time, pause the CPU on QEMU backends
    freeze_vm() if (check_var('BACKEND', 'qemu'));

    diag "Comparing data integrity calculated with SHA256 digest against checksum from IBS/OBS via rsync.pl";
    foreach my $image (grep { /^CHECKSUM_/ } keys %bmwqemu::vars) {
        my $checksum = get_required_var $image;
        $image =~ s/CHECKSUM_//;
        my $image_path = get_required_var $image;
        $image_path = $dir_path . basename($image_path) if $dir_path;
        my $digest = digest_file_hex($image_path, "SHA-256");
        record_info("$image Ok", "$image_path: Ok") && next if $checksum eq $digest;
        my $msg_fail = "SHA256 checksum does not match for $image:\n\tCalculated: $digest\n\tExpected:   $checksum";
        record_info("$image Fail", $msg_fail, result => 'fail');
    }

    resume_vm() if (check_var('BACKEND', 'qemu'));

}

1;
