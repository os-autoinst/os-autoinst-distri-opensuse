# SUSE's openQA tests
#
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
package reboot_and_wait_up;
use strict;
use warnings;
use File::Basename;
use base "opensusebasetest";
use testapi;

sub reboot_and_wait_up() {
    my $self           = shift;
    my $reboot_timeout = shift;

    select_console('root-console');
    type_string("/sbin/reboot\n");
    reset_consoles;
    sleep 2;
    #add switch xen kernel
    assert_screen "grub2", 120;
    if (!get_var("reboot_for_upgrade_step")) {
        if (get_var("XEN") || check_var("HOST_HYPERVISOR", "xen")) {
            send_key_until_needlematch("bootmenu-xen-kernel", 'down', 10, 1);
            send_key 'ret';
        }
    }
    assert_screen(["displaymanager", "virttest-displaymanager"], $reboot_timeout);
    select_console('root-console');

}

1;

