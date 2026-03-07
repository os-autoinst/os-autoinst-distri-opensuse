=head1 data_integrity_utils

Library to verify image data integrity by comparing SHA256/SHA512 checksums

=cut
# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Library to verify image data integrity by comparing SHA256/SHA512 checksums.
# Maintainer: Joaquín Rivera <jeriveramoya@suse.com>

package data_integrity_utils;

use base Exporter;
use Exporter;
use strict;
use warnings;
use testapi;
use Utils::Backends;
use File::Basename;
use Digest::file 'digest_file_hex';
use version_utils qw(is_vmware);

our @EXPORT = qw(verify_checksum get_image_digest);

=head2 get_image_digest

 get_image_digest($image_path);

Returns image digest. Image path C<$image_path> is the parameter which is used to get image digest.
Digest retrieval is platform-specific depends.

=cut

sub get_image_digest {
    my ($image_path, $algorithm) = @_;
    $algorithm ||= 'SHA-256';  # default

    my $digest;
    if (is_svirt) {
        if (check_var('VIRSH_VMM_FAMILY', 'hyperv')) {
            # Use Windows built-in Get-FileHash on Hyper-V, no need for external sha256sum/sha512sum
            my $algo = $algorithm eq 'SHA-512' ? 'SHA512' : 'SHA256';
            $digest = console('svirt')->get_cmd_output(
                "powershell -Command \"(Get-FileHash -Path '$image_path' -Algorithm $algo).Hash.ToLower()\"");
            $digest =~ s/^\s+|\s+$//g;    # trim whitespace
        } else {
            my $cmd = $algorithm eq 'SHA-512' ? 'sha512sum' : 'sha256sum';
            $digest = console('svirt')->get_cmd_output("$cmd $image_path", {domain => is_vmware() ? 'sshVMwareServer' : undef});
            my $len = $algorithm eq 'SHA-512' ? 128 : 64;
            $digest = substr $digest, 0, $len;    # extract hash from the output
        }
    }
    else {
        $digest = digest_file_hex($image_path, $algorithm);
    }
    return $digest;
}

=head2 verify_checksum

 verify_checksum($dir_path);

Verify image data integrity by comparing SHA256/SHA512 checksums.
Directory path C<$dir_path> is the parameter which is a part of image path '$image_path' if exists.

Returns error message in case of failure, empty string in case of success.

=cut

sub verify_checksum {
    my ($dir_path) = shift;
    my $error = '';
    diag "Comparing data integrity calculated with SHA256/SHA512 digest against checksum from IBS/OBS via rsync.pl";
    foreach my $image (grep { /^CHECKSUM_/ } keys %bmwqemu::vars) {
        my $checksum = get_required_var $image;
        $image =~ s/CHECKSUM_//;
        my $image_path = get_required_var $image;
        $image_path = $dir_path . basename($image_path) if $dir_path;
        my $algorithm = length($checksum) == 128 ? 'SHA-512' : 'SHA-256';
        my $digest = get_image_digest($image_path, $algorithm);
        unless ($digest) {
            $error .= "Failed to calculate checksum for $image located in: $image_path\n";
            next;
        }
        if ($checksum eq $digest) {
            diag("$image OK\n$image_path: OK");
        } else {
            $error .= "$algorithm checksum does not match for $image:\n\tCalculated: $digest\n\tExpected:   $checksum\n";
        }
    }
    diag($error) if $error;
    return $error;
}

1;
