# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Bootloader to setup boot process on powerVM
# Maintainer: Stephan Kulow <coolo@suse.com>

use base "installbasetest";
use strict;

use utils;
use testapi;
use lockapi;
use bootloader_setup;
use registration;

sub get_into_net_boot {
    assert_screen 'pvm-bootmenu';

    # 5.   Select Boot Options
    type_string "5\n";
    assert_screen 'pvm-bootmenu-boot-order';

    # 1.   Select Install/Boot Device
    type_string "1\n";
    assert_screen 'pvm-bootmenu-boot-device-type';

    # 4.   Network
    type_string "4\n";
    assert_screen 'pvm-bootmenu-boot-network-service';

    # 1.   BOOTP
    type_string "1\n";
    assert_screen 'pvm-bootmenu-boot-select-device';

    # primary disk
    type_string "1\n";
    assert_screen 'pvm-bootmenu-boot-mode';

    # 2.   Normal Mode Boot
    type_string "2\n";
    assert_screen 'pvm-bootmenu-boot-exit';

    type_string "1\n";
    assert_screen ["pvm-grub", "novalink-failed-first-boot"];
}

sub run {
    my $lpar_id  = get_required_var('NOVALINK_LPAR_ID');
    my $novalink = select_console 'novalink-ssh';

    # detach possibly attached terminals - might be left over
    type_string "rmvterm --id $lpar_id && echo 'DONE'\n";
    assert_screen 'pvm-vterm-closed';

    # power off the machine if it's still running - and don't give it a 2nd chance
    type_string " pvmctl lpar power-off -i id=$lpar_id --hard\n";
    assert_screen [qw(pvm-poweroff-successful pvm-poweroff-not-running)], 180;

    # we assume the lpar is configured to boot normally
    # pvmctl lpar update -i id=<LPARID> --set-fields LogicalPartition.bootmode=Normal
    type_string " pvmctl lpar power-on -i id=$lpar_id --bootmode sms\n";
    assert_screen "pvm-poweron-successful";

    # don't wait for it, otherwise we miss the menu
    type_string " mkvterm --id $lpar_id\n";
    get_into_net_boot;

    # the grub on powerVM has a rather strange feature that it will boot
    # into the firmware if the lpar was reconfigured in between and the
    # first menu entry was used to enter the command line. So we need to
    # reset the LPAR manually
    if (match_has_tag('novalink-failed-first-boot')) {
        type_string "set-default ibm,fw-nbr-reboots\n";
        type_string "reset-all\n";
        assert_screen 'pvm-firmware-prompt';
        send_key '1';
        get_into_net_boot;
    }
    # try 3 times but wait a long time in between - if we're too eager
    # we end with ccc in the prompt
    send_key_until_needlematch('pvm-grub-command-line', 'c', 3, 5);

    # clear the prompt (and create an error) in case the above went wrong
    type_string "\n";

    my $repo     = get_required_var('REPO_0');
    my $mirror   = get_netboot_mirror;
    my $mntpoint = "mnt/openqa/repo/$repo/boot/ppc64le";
    type_string "linux $mntpoint/linux vga=normal console=hvc0 install=$mirror ";
    type_string "sshd=1 sshpassword=$testapi::password\n";

    type_string "initrd $mntpoint/initrd\n";
    save_screenshot;
    type_string "boot\n";
    save_screenshot;

    assert_screen("novalink-successful-first-boot", 120);
}

1;
