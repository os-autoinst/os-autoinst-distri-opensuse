# SUSE's openQA tests
#
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: virt_autotest: the initial version of virtualization automation test in openqa, with kvm and xen support fully
# Maintainer: alice <xlai@suse.com>

package login_console;
use base 'y2_installbase';
use strict;
use warnings;
use File::Basename;
use testapi;
use Utils::Architectures;
use Utils::Backends qw(use_ssh_serial_console is_remote_backend set_ssh_console_timeout);
use ipmi_backend_utils;
use virt_autotest::utils qw(is_xen_host check_port_state check_host_health);
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

#Just only match bootmenu-xen-kernel needle was not enough for xen host if got Xen domain0 kernel panic(bsc#1192258)
#Need to double-check xen role after matched bootmenu-xen-kernel needle successfully
sub double_check_xen_role {
    record_info 'INFO', 'Double-check xen kernel';
    if (script_run('lsmod | grep xen') == 0) {
        diag("Boot up xen kernel successfully");
    }
    else {
        record_info 'INFO', 'Check Xen hypervisor as Grub2 menuentry';
        die 'Check Xen hypervisor as Grub2 menuentry failed' if (script_run('grub2-once --list | grep Xen') != 0);
        save_screenshot;
        die 'Double-check xen kernel failed';
    }

    record_info 'INFO', 'Check if start bootloader from a read-only snapshot';
    assert_script_run('touch /root/read-only.fs && rm -rf /root/read-only.fs');
    save_screenshot;
}

#Explanation for parameters introduced to facilitate offline host upgrade:
#OFFLINE_UPGRADE indicates whether host upgrade is offline which needs reboot
#the host and upgrade from installation media. Please refer to this document:
#https://susedoc.github.io/doc-sle/main/single-html/SLES-upgrade/#cha-upgrade-offline
#UPGRADE_AFTER_REBOOT is used to control whether reboot is followed by host
#offline upgrade procedure which needs to be treated differently compared with
#usual reboot and then login.
#REBOOT_AFTER_UPGRADE is used to control whether current reboot immediately
#follows upgrade, because certain checks are not suitable for this specific
#scenario, for example, xen kernel checking should be skipped for this reboot
#into default kvm environment after upgrading xen host.
#AFTER_UPGRADE indicates whether the whole upgrade process finishes.
sub login_to_console {
    my ($self, $timeout, $counter) = @_;
    $timeout //= 5;
    $counter //= 240;

    if (is_s390x) {
        #Switch to s390x lpar console
        reset_consoles;
        my $svirt = select_console('svirt', await_console => 0);
        return;
    }

    reset_consoles;
    reset_consoles;
    if (is_remote_backend && is_aarch64 && get_var('IPMI_HW') eq 'thunderx') {
        select_console 'sol', await_console => 1;
        send_key 'ret';
        ipmi_backend_utils::ipmitool 'chassis power reset';
    }
    else {
        select_console 'sol', await_console => 0;
    }

    if (check_var('PERF_KERNEL', '1') or check_var('CPU_BUGS', '1') or check_var('VT_PERF', '1')) {
        if (get_var("XEN") && check_var('CPU_BUGS', '1')) {
            assert_screen([qw(pxe-qa-net-mitigation qa-net-selection)], 90);
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

    if (!get_var('UPGRADE_AFTER_REBOOT')) {
        set_var('REBOOT_AFTER_UPGRADE', '') if (get_var('REBOOT_AFTER_UPGRADE'));
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
        if (get_var('OFFLINE_UPGRADE')) {
            #boot to upgrade menuentry
            send_key 'down';
            send_key 'ret';
            #wait sshd up
            die "Can not connect to machine to perform offline upgrade via ssh" unless (check_port_state(get_required_var('SUT_IP'), 22, 10));
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
            save_screenshot;
            send_key 'ret';
            #wait grub2 boot menu after first stage upgrade
            assert_screen('grub2', 300);
            #wait sshd up after first stage upgrade
            die "Can not connect to machine to perform offline upgrade second stage via ssh" unless (check_port_state(get_required_var('SUT_IP'), 22, 20));
            save_screenshot;
            #switch to ssh console
            use_ssh_serial_console;
            save_screenshot;
            #start second stage upgrade
            enter_cmd("DISPLAY= yast.ssh");
            save_screenshot;
            #wait for second stage upgrade completion
            assert_screen('yast2-second-stage-done', 300);
            #leave ssh console and switch to sol console
            switch_from_ssh_to_sol_console(reset_console_flag => 'on');
            save_screenshot;
            send_key 'ret';
            save_screenshot;
        }
        #setup vars
        set_var('UPGRADE_AFTER_REBOOT', '');
        set_var('REBOOT_AFTER_UPGRADE', '1');
        set_var('AFTER_UPGRADE', '1');
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
    set_ssh_console_timeout_before_use if (is_remote_backend && is_aarch64 && get_var('IPMI_HW') eq 'thunderx');
    # use console based on ssh to avoid unstable ipmi
    use_ssh_serial_console;
    # double-check xen role for xen host
    double_check_xen_role if (is_xen_host and !get_var('REBOOT_AFTER_UPGRADE'));
}

sub run {
    my $self = shift;
    $self->login_to_console;
    check_host_health();
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

