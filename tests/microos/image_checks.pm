# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run simple image specific checks
# Maintainer: Fabian Vogt <fvogt@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use version_utils qw(is_microos is_sle_micro is_jeos);
use Utils::Architectures qw(is_aarch64);

sub run {
    select_console 'root-console';

    # Disk which /var resides on
    my $device = script_output 'findmnt -nrvoSOURCE /var';
    if (index($device, "/dev/mapper/") != -1) {
        $device = script_output 'blkid -l -t TYPE="crypto_LUKS" -o device';
    }
    my $disk = script_output "lsblk -rndoPKNAME $device";

    # Verify that openQA resized the disk image
    my $disksize = script_output "sfdisk --show-size /dev/$disk";
    die "Disk not bigger than the default size, got $disksize KiB" unless $disksize > (20 * 1024 * 1024);

    # Verify that the GPT has no errors (PMBR mismatch, backup GPT not at the end)
    # by looking for nonempty stderr.
    die 'GPT has errors' if script_output("sfdisk --list-free /dev/$disk 2>&1 >/dev/null", proceed_on_failure => 0) ne '';

    # Verify that there is no unpartitioned space left
    my $left_sectors = (is_sle_micro("5.4+") && is_aarch64) ? 2048 : 0;
    validate_script_output("sfdisk --list-free /dev/$disk", qr/Unpartitioned space .* $left_sectors sectors/);

    # Verify that the filesystem mounted at /var grew beyond the default 5GiB
    my $varsize = script_output "findmnt -rnboSIZE -T/var";
    die "/var did not grow, got $varsize B" unless $varsize > (5 * 1024 * 1024 * 1024);

    if (get_var("FIRST_BOOT_CONFIG", is_jeos ? "wizard" : "combustion+ignition") =~ /combustion/) {
        # Verify that combustion ran
        validate_script_output('cat /usr/share/combustion-welcome', qr/Combustion was here/);
    }
}

1;
