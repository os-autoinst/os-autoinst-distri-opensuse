# SUSE's openQA tests
#
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
package login_console;
# Summary: virt_autotest: the initial version of virtualization automation test in openqa, with kvm support fully, xen support not done yet
# Maintainer: alice <xlai@suse.com>

use strict;
use warnings;
use File::Basename;
use base "opensusebasetest";
use testapi;
use virt_utils;

sub login_to_console() {
    my $timeout = shift;
    $timeout //= 300;

    #setup needle tag
    my $displaymanager_tag = "displaymanager";
    if (check_var("INSTALL_TO_SLE11", "yes")) {
        $displaymanager_tag = "displaymanager-sle11";
    }
    if (check_var("reboot_for_upgrade_step", "yes") || check_var("after_upgrade", "yes")) {
        $displaymanager_tag = "displaymanager";
    }

    # Wait for bootload for the first time.
    assert_screen([qw(grub2 grub1)], 120);
    if (!get_var("reboot_for_upgrade_step")) {
        if (get_var("XEN") || check_var("HOST_HYPERVISOR", "xen")) {
            send_key_until_needlematch("virttest-bootmenu-xen-kernel", 'down', 10, 1);
            send_key 'ret';
        }
    }
    else {
        set_var("reboot_for_upgrade_step", undef);
        set_var("after_upgrade",           "yes");
    }

    assert_screen(["$displaymanager_tag", "virttest-displaymanager"], $timeout);

    select_console('root-console');
}

sub run() {
    login_to_console;
    set_serialdev;
}

1;

