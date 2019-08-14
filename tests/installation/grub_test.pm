# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Handle grub menu after reboot
# - Handle grub2 to boot from hard disk (opposed to installation)
# - Handle passphrase for encrypted disks
# - Handle booting of snapshot or XEN, acconding to BOOT_TO_SNAPSHOT or XEN
# - Enable plymouth debug if product if GRUB_KERNEL_OPTION_APPEND is set,
# or product is sle, aarch64 and PLYMOUTH_DEBUG is set
# Tags: poo#9716, poo#10286, poo#10164
# Maintainer: Martin Kravec <mkravec@suse.com>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use utils;
use version_utils 'is_sle';
use bootloader_setup qw(stop_grub_timeout boot_into_snapshot);

=head2 handle_installer_medium_bootup

Due to pre-installation setup, qemu boot order is always booting from CD-ROM.
=cut
sub handle_installer_medium_bootup {
    my ($self) = @_;

    return unless (check_var("BOOTFROM", "d") || (get_var('UEFI') && get_var('USBBOOT')));
    assert_screen 'inst-bootmenu';

    if (check_var("BOOTFROM", "d") && check_var("AUTOUPGRADE") && check_var("PATCH")) {
        assert_screen 'grub2';
    }

    send_key_until_needlematch 'inst-bootmenu-boot-harddisk', 'up';
    send_key 'ret';

    # use firmware boot manager of aarch64 to boot upgraded system
    $self->handle_uefi_boot_disk_workaround if (check_var('ARCH', 'aarch64'));
}

sub bug_workaround_bsc1005313 {
    record_soft_failure "Running with plymouth:debug to catch bsc#1005313" if get_var('PLYMOUTH_DEBUG');
    send_key 'e';
    # Move to end of kernel boot parameters line
    send_key_until_needlematch "linux-line-selected", "down";
    send_key "end";

    assert_screen "linux-line-matched";
    if (get_var('PLYMOUTH_DEBUG')) {
        # remove "splash=silent quiet showopts"
        for (1 .. 28) { send_key "backspace" }
        type_string 'plymouth:debug';
    }
    type_string " " . get_var('GRUB_KERNEL_OPTION_APPEND') if get_var('GRUB_KERNEL_OPTION_APPEND');

    save_screenshot;
    send_key 'ctrl-x';
}

sub run {
    my ($self) = @_;
    my $timeout = get_var('GRUB_TIMEOUT', 90);

    $self->handle_installer_medium_bootup;
    workaround_type_encrypted_passphrase;
    # 60 due to rare slowness e.g. multipath poo#11908
    # 90 as a workaround due to the qemu backend fallout
    assert_screen_with_soft_timeout('grub2', timeout => 2 * $timeout, soft_timeout => $timeout, bugref => 'boo#1120256');
    stop_grub_timeout;
    boot_into_snapshot if get_var("BOOT_TO_SNAPSHOT");
    send_key_until_needlematch("bootmenu-xen-kernel", 'down', 10, 5) if get_var('XEN');
    if ((check_var('ARCH', 'aarch64') && is_sle && get_var('PLYMOUTH_DEBUG'))
        || get_var('GRUB_KERNEL_OPTION_APPEND'))
    {
        $self->bug_workaround_bsc1005313 unless get_var("BOOT_TO_SNAPSHOT");
    }
    else {
        # avoid timeout for booting to HDD
        send_key 'ret';
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
