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
use Utils::Backends qw(use_ssh_serial_console is_remote_backend);
use ipmi_backend_utils;

use IPC::Run;
sub ipmitool {
    my ($cmd) = @_;

    my @cmd = ('ipmitool', '-I', 'lanplus', '-H', $bmwqemu::vars{IPMI_HOSTNAME}, '-U', $bmwqemu::vars{IPMI_USER}, '-P', $bmwqemu::vars{IPMI_PASSWORD});
    push(@cmd, split(/ /, $cmd));

    my ($stdin, $stdout, $stderr, $ret);
    $ret = IPC::Run::run(\@cmd, \$stdin, \$stdout, \$stderr);
    chomp $stdout;
    chomp $stderr;

    bmwqemu::diag("IPMI: $stdout");
    return $stdout;
}

sub login_to_console {
    my ($self, $timeout) = @_;
    $timeout //= 240;

    if (check_var('PERF_KERNEL', '1')) {
        reset_consoles;
        select_console 'sol', await_console => 0;
        send_key_until_needlematch(['linux-login', 'virttest-displaymanager'], 'ret', $timeout, 5);
        #use console based on ssh to avoid unstable ipmi
        save_screenshot;
        use_ssh_serial_console;
        return;
    }

    if (check_var('ARCH', 's390x')) {
        #Switch to s390x lpar console
        reset_consoles;
        my $svirt = select_console('svirt', await_console => 0);
        return;
    }

    reset_consoles;
    select_console 'sol', await_console => 0;

    my $sut_machine = get_var('SUT_IP', 'nosutip');
    boot_local_disk_arm_huawei if (is_remote_backend && check_var('ARCH', 'aarch64') && ($sut_machine =~ /huawei/img));

    if (!check_screen([qw(grub2 grub1 prague-pxe-menu)], 210)) {
        ipmitool("chassis power reset");
        reset_consoles;
        select_console 'sol', await_console => 0;
        assert_screen([qw(grub2 grub1 prague-pxe-menu)], 90);
    }

    # If a PXE menu will appear just select the default option (and save us the time)
    if (match_has_tag('prague-pxe-menu')) {
        send_key 'ret';

        assert_screen([qw(grub2 grub1)], 60);
    }

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
            my $upgrade_machine = get_var('SUT_IP', 'nosutip');
            if (is_remote_backend && check_var('ARCH', 'aarch64') && ($upgrade_machine =~ /huawei/img)) {
                wait_still_screen 10;
                boot_local_disk_arm_huawei;
            }
            my $host_installed_version = get_var('VERSION_TO_INSTALL', get_var('VERSION', ''));
            ($host_installed_version) = $host_installed_version =~ /^(\d+)/im;
            my $host_upgrade_version  = get_required_var('UPGRADE_PRODUCT');         #format sles-15-sp0
            my ($host_upgrade_relver) = $host_upgrade_version =~ /sles-(\d+)-sp/i;
            my ($host_upgrade_spver)  = $host_upgrade_version =~ /sp(\d+)$/im;
            if (($host_installed_version eq '11') && (($host_upgrade_relver eq '15' && $host_upgrade_spver eq '0') || ($host_upgrade_relver eq '12' && $host_upgrade_spver eq '5'))) {
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

    sleep 30;    # Wait for the GRUB to disappier (there's no chance for the system to boot faster
    save_screenshot;

    for (my $i = 0; $i <= 4; $i++) {
        last if (check_screen([qw(linux-login virttest-displaymanager)], 60));
        save_screenshot;
        send_key 'ret';
    }

    # use console based on ssh to avoid unstable ipmi
    use_ssh_serial_console;

}

sub run {
    my $self = shift;
    $self->login_to_console;
}

1;

