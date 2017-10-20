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
use ipmi_backend_utils;

sub login_to_console {
    my ($self, $timeout) = @_;
    $timeout //= 120;

    reset_consoles;
    select_console 'sol', await_console => 0;

    # Wait for bootload for the first time.
    assert_screen([qw(grub2 grub1)], 420);

    if (!get_var("reboot_for_upgrade_step")) {
        if (get_var("XEN") || check_var("HOST_HYPERVISOR", "xen")) {
            #send key 'up' to stop grub timer counting down, to be more robust to select xen
            send_key 'up';
            send_key_until_needlematch("virttest-bootmenu-xen-kernel", 'down', 10, 3);
        }
    }
    else {
        set_var("reboot_for_upgrade_step", undef);
        set_var("after_upgrade",           "yes");
    }
    send_key 'ret';

    assert_screen(['linux-login', 'virttest-displaymanager'], $timeout);

    #use console based on ssh to avoid unstable ipmi
    use_ssh_serial_console;
}

sub run {
    my $self = shift;
    $self->login_to_console;
}

1;

