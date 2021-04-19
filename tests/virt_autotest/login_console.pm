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
use base 'y2_installbase';
use strict;
use warnings;
use File::Basename;
use testapi;
use Utils::Backends qw(use_ssh_serial_console is_remote_backend set_ssh_console_timeout);
use ipmi_backend_utils;
use virt_autotest::utils qw(is_xen_host);
use IPC::Run;

sub set_ssh_console_timeout_before_use {
    reset_consoles;
    select_console('root-console');
    set_ssh_console_timeout('/etc/ssh/sshd_config', '28800');
    reset_consoles;
    select_console 'sol', await_console => 1;
    send_key 'ret';
    check_screen([qw(linux-login virttest-displaymanager)], 60);
    save_screenshot;
    send_key 'ret';
}

sub login_to_console {
    my ($self, $timeout, $counter) = @_;
    $timeout //= 5;
    $counter //= 240;

    if (check_var('ARCH', 's390x')) {
        #Switch to s390x lpar console
        reset_consoles;
        my $svirt = select_console('svirt', await_console => 0);
        return;
    }

    reset_consoles;
    reset_consoles;
    if (is_remote_backend && check_var('ARCH', 'aarch64') && get_var('IPMI_HW') eq 'thunderx') {
        select_console 'sol', await_console => 1;
        send_key 'ret';
        ipmi_backend_utils::ipmitool 'chassis power reset';
    }
    else {
        select_console 'sol', await_console => 0;
    }

    if (check_var('PERF_KERNEL', '1') or check_var('CPU_BUGS', '1') or check_var('VT_PERF', '1')) {
        if (get_var("XEN") && check_var('CPU_BUGS', '1')) {
            assert_screen 'pxe-qa-net-mitigation', 90;
            send_key 'ret';
            assert_screen([qw(grub2 grub1)], 60);
            send_key 'up';
        }
        else {
            send_key_until_needlematch(['linux-login', 'virttest-displaymanager'], 'ret', $counter, $timeout);
            #use console based on ssh to avoid unstable ipmi
            save_screenshot;
            use_ssh_serial_console;
            return;
        }
    }

    if (!check_screen([qw(grub2 grub1 prague-pxe-menu)], 210)) {
        ipmitool("chassis power reset");
        reset_consoles;
        select_console 'sol', await_console => 0;
        check_screen([qw(grub2 grub1 prague-pxe-menu)], 90);
    }

    # If a PXE menu will appear just select the default option (and save us the time)
    if (match_has_tag('prague-pxe-menu')) {
        send_key 'ret';

        check_screen([qw(grub2 grub1)], 60);
    }

    if (!get_var("reboot_for_upgrade_step")) {
        if (is_xen_host) {
            #send key 'up' to stop grub timer counting down, to be more robust to select xen
            send_key 'up';
            save_screenshot;

            for (1 .. 20) {
                if ($_ == 10) {
                    reset_consoles;
                    select_console 'sol', await_console => 0;
                }
                send_key 'down';
                last if check_screen 'virttest-bootmenu-xen-kernel', 5;
            }
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
            enter_cmd("DISPLAY= yast.ssh");
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

    sleep 30;    # Wait for the GRUB to disappier (there's no chance for the system to boot faster
    save_screenshot;

    for (my $i = 0; $i <= 4; $i++) {
        last if (check_screen([qw(linux-login virttest-displaymanager)], 60));
        save_screenshot;
        send_key 'ret';
    }

    # Set ssh console timeout for thunderx machine
    set_ssh_console_timeout_before_use if (is_remote_backend && check_var('ARCH', 'aarch64') && get_var('IPMI_HW') eq 'thunderx');
    # use console based on ssh to avoid unstable ipmi
    use_ssh_serial_console;

}

sub run {
    my $self = shift;
    $self->login_to_console;
}

sub post_fail_hook {
    my ($self) = @_;
    if (check_var('PERF_KERNEL', '1')) {
        select_console 'log-console';
        save_screenshot;
        script_run "save_y2logs /tmp/y2logs.tar.bz2";
        upload_logs "/tmp/y2logs.tar.bz2";
        save_screenshot;
    }
    else {
        $self->SUPER::post_fail_hook;
    }
}

1;

