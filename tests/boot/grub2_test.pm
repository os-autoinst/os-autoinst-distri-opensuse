# SUSE's openQA tests
#
# Copyright © 2019-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Grub2 test
#           - boot another menu entry
#           - command & menu edit
#           - boot into emergency shell
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
    assert_screen 'grub2', 120;
    stop_grub_timeout;
}

sub edit_cmdline {
    send_key 'e';
    for (1 .. 13) { send_key 'down'; }
    send_key_until_needlematch 'grub2-edit-linux-line', 'down';
    send_key 'end';
}

sub grub2_boot {
    sleep 1;
    save_screenshot;
    send_key 'f10';
}

sub run {
    select_console 'root-console';
    # remove splash and quiet parameters from cmdline, grub config will be updated with following kernel installation
    assert_script_run 'sed -i \'/CMDLINE/s/ quiet//\' /etc/default/grub';
    assert_script_run 'sed -i \'/CMDLINE/s/splash=silent //\' /etc/default/grub';
    assert_script_run 'grep CMDLINE /etc/default/grub';
    record_info 'grub2 menu entry', 'install another kernel, boot the previous one';
    zypper_call 'in -t pattern yast2_basis' if is_sle('15+');
    if (is_sle('15-sp2+')) {
        zypper_ar "http://download.suse.de/ibs/Devel:/Kernel:/vanilla/standard/", name => 'KERNEL_DEVEL';
    }
    else {
        my $LTSS    = get_var('SCC_REGCODE_LTSS') ? '-LTSS' : '';
        my $version = get_var('VERSION') . $LTSS;
        zypper_ar "http://download.suse.de/ibs/Devel:/Kernel:/SLE$version/standard/", name => 'KERNEL_DEVEL';
    }
    zypper_call 'in kernel-vanilla';
    assert_script_run 'uname -r >kernel.txt';
    reboot;
    my $boot_entry = is_sle('=12-sp2') || is_sle('=12-sp3') ? '5' : '3';
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
    edit_cmdline;
    type_string ' single';
    grub2_boot;
    assert_screen 'emergency-shell', 200;
    type_password;
    send_key 'ret';
    assert_script_run 'grep \' single\' /proc/cmdline';
    reboot;

    if (get_var('HDD_1') !~ /lvm/) {    # fips on lvm is not supported
        record_info 'grub2 edit boot entry', 'boot with fips mode';
        edit_cmdline;
        type_string ' fips=1';
        grub2_boot;
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
    # on sle12sp1 will the schortcut change from 't' to 'l' after you press alt-t
    send_key 'alt-t' if is_sle('=12-sp1');
    send_key 'alt-l';    # bootloader options tab
    assert_screen 'installation-bootloader-options';
    my $protect_key = is_sle('=12-sp1') && !get_var('UEFI') ? 'a' : 'e';
    send_key "alt-$protect_key";    # check protect boot loader with pw
    send_key 'alt-r';               # uncheck protect entry modification only
    send_key 'alt-p';               # selecet password field
    type_password;
    send_key 'tab';
    type_password;
    sleep 2;
    save_screenshot;
    send_key 'alt-o';               # OK
    wait_serial 'yast-bootloader-status-0', 60 || die "'yast bootloader' didn't finish";
    # verify password protect
    assert_script_run 'grep \'password\' /boot/grub2/grub.cfg';
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
