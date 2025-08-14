# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Use "yast2 bootloader" to enable or
#          disable secureboot support
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#81712

use base 'opensusebasetest';
use base 'consoletest';
use testapi;
use utils;
use power_action_utils 'power_action';
use version_utils 'is_sle';

sub run {
    my ($self) = shift;

    if (is_sle('>=16')) {
        record_info("SKIPPING TEST - YaST2 is not shipped in SLE16.");
        return;
    }

    # Start yast2 bootloader to un-select Secure Boot Support
    # This operation will not disable the secureboot from UEFI
    # ROM, it will change the bootloader file from shim.efi to
    # grubaa64.efi
    select_console("root-console");

    if (script_run("rpm -q yast2-bootloader")) {
        zypper_call("in yast2-bootloader");
    }

    enter_cmd("yast2 bootloader");
    assert_screen("yast2-bootloder-GRUB2-for-EFI");
    send_key_until_needlematch("yast2_bootloader-Secureboot-Support", "tab", 7, 2);
    send_key("ret");
    assert_screen("yast2_bootloader-Secureboot-unselect");
    send_key_until_needlematch("yast2_bootloader-Secureboot-unselect-ok", "tab", 6, 2);
    send_key("ret");
    reset_consoles;

    # Make sure boot loader does not uses shim any more
    select_console("root-console");
    my $boot_opt = script_output("efibootmgr -v | grep BootOrder|awk '{print \$NF}' | awk -F, '{print \$1}'");
    my $boot_inf = script_output("efibootmgr -v | grep Boot$boot_opt");
    record_info("Bootloader info:", "$boot_inf");
    my $results = script_run("efibootmgr -v | grep Boot$boot_opt | grep shim.efi");
    if (!$results) {
        die("ERROR", "shim.efi is still used, it is not by design");
    }

    # Reboot the node to check again
    # Then both shim.efi and grubaa64.efi can
    # boot up the system successfully
    power_action("reboot", textmode => 1);
    $self->wait_boot(textmode => 1);

    select_console("root-console");
    my $results1 = script_run("efibootmgr -v | grep BootCurrent | grep $boot_opt");
    if ($results1) {
        die("ERROR", "Wrong Bootloder is used");
    }
}

sub test_flags {
    return {always_rollback => 1};
}

1;
