# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Grub2 test
#           - boot another menu entry
#           - command & menu edit
#           - fips
#           - password
#           - with UEFI (secureboot enabled by default)
# Maintainer: Jozef Pupava <jpupava@suse.com>

use strict;
use warnings;
use base 'opensusebasetest';
use testapi;
use bootloader_setup qw(stop_grub_timeout boot_grub_item);
use utils qw(zypper_call zypper_ar);
use version_utils 'is_sle';

sub reboot {
    type_string "reboot\n";
    reset_consoles;
    assert_screen 'grub2';
    stop_grub_timeout;
}

sub run {
    record_info 'grub2 menu entry', 'install another kernel, another kernel will the previous one';
    select_console 'root-console';
    zypper_ar 'http://download.suse.de/ibs/Devel:/Kernel:/master/standard/', 'KERNEL_DEVEL';
    zypper_call 'in kernel-vanilla';
    assert_script_run 'uname -r >kernel.txt';
    reboot;
    my $boot_entry = is_sle('=12-sp3') ? '5' : '3';
    boot_grub_item(2, $boot_entry);
    assert_screen 'linux-login', 200;
    select_console 'root-console';
    assert_script_run 'uname -r|grep $(cat kernel.txt)';
    zypper_call 'rr KERNEL_DEVEL';
    zypper_call 'rm kernel-vanilla';
    zypper_call 'in -t pattern fips';
    assert_script_run 'mkinitrd';
    reboot;

    record_info 'grub2 command line', 'ls /boot and help command';
    send_key 'c';
    type_string "ls /boot\n";
    assert_screen 'grub2-command-line-ls';
    type_string "help\n";
    assert_screen 'grub2-command-line-help';
    send_key 'esc';
    sleep 1;

    record_info 'grub2 boot single user mode', 'add \'single\' boot parameter';
    send_key 'e';
    send_key_until_needlematch 'grub2-edit-linux-line', 'down';
    send_key 'end';
    type_string ' single';
    send_key 'f10';
    assert_screen 'emergency-shell', 200;
    type_password;
    send_key 'ret';
    assert_script_run 'grep \' single\' /proc/cmdline';
    reboot;

    if (get_var('HDD_1') !~ /lvm/) {    # fips on lvm is not supported
        record_info 'grub2 edit boot entry', 'boot with fips mode';
        send_key 'e';
        send_key_until_needlematch 'grub2-edit-linux-line', 'down';
        send_key 'end';
        type_string ' fips=1';
        send_key 'f10';
        assert_screen 'linux-login', 300;
        select_console 'root-console';
        assert_script_run 'grep \'fips=1\' /proc/cmdline';
        assert_script_run 'sysctl crypto.fips_enabled';
    }
    else {
        send_key 'ret';
        assert_screen 'linux-login', 200;
        select_console 'root-console';
    }

    record_info 'grub2 password',                                                    'set password to boot';
    script_run "yast bootloader; echo yast-bootloader-status-\$? > /dev/$serialdev", 0;
    assert_screen 'test-yast2_bootloader-1';
    send_key 'alt-l';    # bootloader options tab
    assert_screen 'installation-bootloader-options';
    send_key 'alt-e';    # check protect boot loader with pw
    send_key 'alt-r';    # uncheck protect entry modification only
    send_key 'alt-p';    # selecet password field
    type_password;
    send_key 'tab';
    type_password;
    sleep 2;
    save_screenshot;
    send_key 'alt-o';    # OK
    wait_serial 'yast-bootloader-status-0', 60 || die "'yast bootloader' didn't finish";
    reboot;

    record_info 'grub2 password', 'type login and password to boot';
    assert_screen 'grub2';
    send_key 'ret';
    type_string 'root';
    send_key 'ret';
    type_password;
    send_key 'ret';
    assert_screen 'linux-login', 100;
}

1;
