# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run simple image specific checks
# Maintainer: Fabian Vogt <fvogt@suse.de>

use base "consoletest";
use testapi;
use version_utils qw(is_microos is_sle_micro is_jeos is_leap_micro);
use Utils::Backends 'is_pvm';
use Utils::Architectures qw(is_aarch64 is_ppc64le);

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
    # openQA cannot resize powerVM disk image since it is not QEMU backend, skip the check here, see poo#167986
    die "Disk not bigger than the default size, got $disksize KiB" unless ($disksize > (20 * 1024 * 1024) || is_pvm);

    # Verify that the GPT has no errors (PMBR mismatch, backup GPT not at the end)
    # by looking for nonempty stderr.
    die 'GPT has errors' if script_output("sfdisk --list-free /dev/$disk 2>&1 >/dev/null", proceed_on_failure => 0) ne '';

    # Verify that there is no unpartitioned space left
    # 0 sectors is default and expected value in most of the images
    my $left_sectors = 0;
    if ((is_sle_micro("6.2+") || is_leap_micro("6.2+") || (is_jeos && is_transactional)) && is_aarch64 && !(get_var('FLAVOR', '') =~ /kvm-and-xen|qcow/i) && !check_var('FROM_VERSION', '6.1')) {
        $left_sectors = 6144;
    } elsif ((is_sle_micro("=6.1") || is_leap_micro("=6.1") || check_var('FROM_VERSION', '6.1')) && is_aarch64 && (get_var('FLAVOR', '') =~ /selfinstall/i)) {
        $left_sectors = 4062;
    } elsif ((is_sle_micro("5.4+") || is_leap_micro("5.4+")) && is_aarch64 && get_var('FLAVOR', '') !~ m/qcow|SelfInstall/) {
        $left_sectors = 2048;
    } elsif ((is_sle_micro("6.0+") && get_required_var('FLAVOR') =~ /ppc-4096/) || (is_sle_micro("6.2+") && is_ppc64le && (get_var('FLAVOR') =~ /qcow/)) ||
        is_jeos && is_ppc64le && check_var('HDDSECTORSIZE_1', '4096')) {
        $left_sectors = 1792;
    }

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
