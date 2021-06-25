# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Verify source disks attached to the test and record a
#          checksum of the files.
# Maintainer: Alvaro Carvajal <acarvajal@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use data_integrity_utils qw(get_image_digest);

sub run {
    my $self     = shift;
    my $numdisks = get_var('NUMDISKS', 1);

    for my $i (1 .. $numdisks) {
        my $disk    = get_var("HDD_$i");
        my $overlay = "raid/hd" . ($i - 1) . "-overlay0";
        if ($disk) {
            my $size     = $disk ? -s $disk : 0;
            my $digest   = get_image_digest($disk);
            my $ovdigest = get_image_digest($overlay);
            record_info "HDD_$i Info", "Name: [$disk]\nSize: [$size]\nDigest: [$digest]\nOverlay Digest: [$ovdigest]";
            diag "HDD_$i Info: Name=[$disk], Size=[$size], Digest=[$digest], Overlay Digest=[$ovdigest]";
        }
        else {
            record_info "HDD_$i Info", "Empty HDD_$i setting";
            diag "HDD_$i Info: empty HDD_$i setting";
        }
    }
}

1;
