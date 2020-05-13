# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run simple image specific checks
# Maintainer: Fabian Vogt <fvogt@suse.de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;

sub run {
    select_console 'root-console';

    # Disk which /var resides on
    my $disk = script_output 'lsblk -rnoPKNAME $(findmnt -nrvoSOURCE /var)';

    # Verify that openQA resized the disk image
    my $disksize = script_output "sfdisk --show-size /dev/$disk";
    die "Disk not bigger than the default size, got $disksize KiB" unless $disksize > (20 * 1024 * 1024);

    # Verify that there is no unpartitioned space left
    validate_script_output("sfdisk --list-free /dev/$disk", qr/Unpartitioned space .* 0 sectors/);

    # Verify that the filesystem mounted at /var grew beyond the default 5GiB
    my $varsize = script_output "findmnt -rnboSIZE -T/var";
    die "/var did not grow, got $varsize B" unless $varsize > (5 * 1024 * 1024 * 1024);
}

1;
