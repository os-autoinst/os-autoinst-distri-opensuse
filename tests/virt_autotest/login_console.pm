# SUSE's openQA tests
#
# Copyright © 2012-2018 SUSE LLC
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
use Utils::Backends 'use_ssh_serial_console';
use ipmi_backend_utils;

sub login_to_console {
    my ($self, $timeout) = @_;
    $timeout //= 240;

    reset_consoles;
    select_console 'sol', await_console => 0;

    # Wait for bootload for the first time.
    assert_screen([qw(grub2 grub1)], 210);

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
            $timeout = 600;
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

            my $host_installed_version = get_var('VERSION_TO_INSTALL', get_var('VERSION', ''));
            ($host_installed_version) = $host_installed_version =~ /^(\d+)/im;
            my $host_upgrade_version = get_required_var('UPGRADE_PRODUCT');         #format sles-15-sp0
            my $host_upgrade_relver  = $host_upgrade_version =~ /sles-(\d+)-sp/i;
            my $host_upgrade_spver   = $host_upgrade_version =~ /sp(\d+)$/im;
            if (($host_installed_version eq '11') && ($host_upgrade_relver eq '15') && ($host_upgrade_spver eq '0')) {
                assert_screen('sshd-server-started-config', 180);
                use_ssh_serial_console;
                save_screenshot;
                #start system first configuration after finishing upgrading from sles-11-sp4
                type_string("yast.ssh\n");
                assert_screen('will-linux-login', $timeout);
                select_console('sol', await_console => 0);
                save_screenshot;
                send_key 'ret';
                save_screenshot;
            }
        }
        #setup vars
        set_var("reboot_for_upgrade_step", undef);
        set_var("after_upgrade",           "yes");
    }
    save_screenshot;
    send_key 'ret';

    send_key_until_needlematch(['linux-login', 'virttest-displaymanager'], 'ret', $timeout / 5, 5);
    #use console based on ssh to avoid unstable ipmi
    save_screenshot;
    use_ssh_serial_console;
}

sub run {
    my $self = shift;
    $self->login_to_console;
}

1;

