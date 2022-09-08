package grub_utils;

use base Exporter;
use Exporter;

use strict;
use warnings;
use opensusebasetest qw(handle_uefi_boot_disk_workaround);
use testapi;
use Utils::Architectures;
use utils;
use version_utils qw(is_sle is_livecd);
use bootloader_setup qw(stop_grub_timeout boot_into_snapshot);

our @EXPORT = qw(
  grub_test
);

=head2

  grub_test();

Handle grub menu after reboot
    - Handle grub2 to boot from hard disk (opposed to installation)
    - Handle passphrase for encrypted disks
    - Handle booting of snapshot or XEN, acconding to BOOT_TO_SNAPSHOT or XEN
    - Enable plymouth debug if product if GRUB_KERNEL_OPTION_APPEND is set,
      or product is sle, aarch64 and PLYMOUTH_DEBUG is set
=cut

sub grub_test {
    my $timeout = get_var('GRUB_TIMEOUT', 200);

    handle_installer_medium_bootup();
    workaround_type_encrypted_passphrase;
    # 60 due to rare slowness e.g. multipath poo#11908
    # 90 as a workaround due to the qemu backend fallout
    assert_screen('grub2', $timeout);
    stop_grub_timeout;
    boot_into_snapshot if get_var("BOOT_TO_SNAPSHOT");
    send_key_until_needlematch("bootmenu-xen-kernel", 'down', 11, 5) if get_var('XEN');
    if ((is_aarch64 && is_sle && get_var('PLYMOUTH_DEBUG'))
        || get_var('GRUB_KERNEL_OPTION_APPEND'))
    {
        bug_workaround_bsc1005313() unless get_var("BOOT_TO_SNAPSHOT");
    }
    else {
        # avoid timeout for booting to HDD
        send_key 'ret';
    }
    # Avoid return key not received occasionally for hyperv-uefi guest at first boot
    send_key 'ret' if (check_var('VIRSH_VMM_FAMILY', 'hyperv') && get_var('UEFI'));
}

=head2 handle_installer_medium_bootup

Due to pre-installation setup, qemu boot order is always booting from CD-ROM.
=cut

sub handle_installer_medium_bootup {
    return unless (check_var("BOOTFROM", "d") || (get_var('UEFI') && get_var('USBBOOT')));
    assert_screen 'inst-bootmenu', 180;

    # Layout of live is different from installation media
    my $key = is_livecd() ? 'down' : 'up';
    send_key_until_needlematch 'inst-bootmenu-boot-harddisk', $key;
    send_key 'ret';

    # use firmware boot manager of aarch64 to boot upgraded system
    'opensusebasetest'->handle_uefi_boot_disk_workaround() if (is_aarch64);
}

sub bug_workaround_bsc1005313 {
    record_soft_failure "Running with plymouth:debug to catch bsc#1005313" if get_var('PLYMOUTH_DEBUG');
    send_key 'e';
    # Move to end of kernel boot parameters line
    send_key_until_needlematch "linux-line-selected", "down", 26;
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

1;
