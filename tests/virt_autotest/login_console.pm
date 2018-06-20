# SUSE's openQA tests
#
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: virt_autotest: the initial version of virtualization automation test in openqa, with kvm and xen support fully
# Maintainer: alice <xlai@suse.com>

package login_console;
use base "y2logsstep";
use strict;
use warnings;
use File::Basename;
use testapi;
use ipmi_backend_utils;

sub login_to_console {
    my ($self, $timeout) = @_;
    $timeout //= 120;

    reset_consoles;
    select_console 'sol', await_console => 0;

    # Wait for bootload for the first time.
    assert_screen([qw(grub2 grub1)], 120);

    if (!get_var("reboot_for_upgrade_step")) {
        if (get_var("XEN") || check_var("HOST_HYPERVISOR", "xen")) {
            #send key 'up' to stop grub timer counting down, to be more robust to select xen
            send_key 'up';
            save_screenshot;
            send_key_until_needlematch("virttest-bootmenu-xen-kernel", 'down', 10, 5);
        }
    }
    else {
        save_screenshot;
        #offline upgrade requires upgrading offline during reboot while online doesn't
        if (check_var('offline_upgrade', 'yes')) {
            #boot to upgrade menuentry
            send_key 'down';
            send_key 'ret';
            #wait sshd up
            assert_screen('sshd-server-started', 180);
            save_screenshot;
            #switch to ssh console
            use_ssh_serial_console;
            save_screenshot;
            #start upgrade
            type_string("DISPLAY= yast.ssh\n");
            save_screenshot;
            #wait upgrade finish
            assert_screen('rebootnow', 2700);
            save_screenshot;
            send_key 'ret';
            #leave ssh console and switch to sol console
            switch_from_ssh_to_sol_console(reset_console_flag => 'on');
            #grub may not showup after upgrade because default GRUB_TERMINAL setting
            #when fixed in separate PR, will uncomment following line
            #assert_screen([qw(grub2 grub1)], 120);
        }
        #setup vars
        set_var("reboot_for_upgrade_step", undef);
        set_var("after_upgrade",           "yes");
    }
    save_screenshot;
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

