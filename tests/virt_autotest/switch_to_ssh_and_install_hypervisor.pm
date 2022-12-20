# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: For openSUSE virtualization test only. login in console, install kvm/xen patterns if needed.
#  - Even if you'd like to run tests without host installation(DO_NOT_INSTALL_HOST=1), this module is still necessary as login console in this module is required.
#  - This module is added for openSUSE TW because of the difference between SLE and TW. Meanwile, login_console, install_package and update_package from SLE are not needed. The reasons are listed below:
#    -- login_console is not called after first boot in host installation in TW because kvm/xen patterns have not been installed at that time. reconnect_mgmt_console and first_boot take care of the login function.
#    -- have to zypper install kvm/xen patterns in TW.
#    -- no QA packages have been required any more.
#    -- no update is needed as it is Tumbleweed.
#    -- reboot is needed after kvm/xen patterns are installed so the module must run before reboot_and_wait_up_normal. login_console will still be called by reboot_and_wait_up_normal.
# Maintainer: Julie CAO <jcao@suse.com>

use strict;
use warnings;
use base 'virt_autotest_base';
use testapi;
use ipmi_backend_utils;
use Utils::Backends qw(use_ssh_serial_console is_remote_backend);
use utils qw(zypper_call systemctl permit_root_ssh_in_sol);
use virt_autotest::utils qw(is_kvm_host is_xen_host);

sub run {

    #enable ssh root access for openSUSE TW in sol console
    #root access is not permitted by default in TW, see bsc#1173067#c2
    select_console 'sol', await_console => 0;
    for (my $i = 0; $i <= 4; $i++) {
        send_key 'ret' if check_screen('sol-console-wait-typing-ret', 60);
        last if (check_screen([qw(linux-login text-login)], 60));
        save_screenshot;
    }

    if (check_screen('text-login')) {
        enter_cmd "root";
        assert_screen "password-prompt";
        type_password;
        send_key('ret');
    }
    assert_screen "text-logged-in-root";
    #skip TW host installation and directly login if you'd like to run test on an SUT with TW installed
    permit_root_ssh_in_sol unless get_var('DO_NOT_INSTALL_HOST');
    select_console('root-ssh');

    return if get_var('DO_NOT_INSTALL_HOST');

    die 'Need one of both to be true: is_kvm_host || is_xen_host' unless is_kvm_host || is_xen_host;
    my $hypervisor = is_kvm_host ? 'kvm' : 'xen';
    zypper_call('--gpg-auto-import-keys ref');
    zypper_call("in -t pattern ${hypervisor}_server ${hypervisor}_tools", 1800);
    set_grub_on_vh('', '', $hypervisor);
    systemctl 'enable libvirtd', ignore_failure => 1;

    virt_autotest::utils::install_default_packages();
    save_screenshot;

    #set up necessary network bridge br0 for kvm/xen hypervisor.
    #SLE sets up br0 during installation as kvm/xen role, while openSUSE TW does not.
    #change MACAddressPolicy to none, or the network bridge will get a different MAC address from its enslave
    #it is specific to TW because it uses udev naming scheme v247, see bsc#1136600
    my $bridge_rule_file = "/usr/lib/systemd/network/98-default-bridge.link";
    assert_script_run("echo \"[Match]\nDriver=bridge\n\n[Link]\nMACAddressPolicy=none\" > $bridge_rule_file", 60);
    my $default_netdevice = get_var('SUT_NETDEVICE', 'eno1');
    script_run("echo \"BOOTPROTO='dhcp'\nSTARTMODE='auto'\nBRIDGE='yes'\nBRIDGE_PORTS='$default_netdevice'\" > /etc/sysconfig/network/ifcfg-br0");
    script_run("echo \"BOOTPROTO='none'\nSTARTMODE='auto'\" > /etc/sysconfig/network/ifcfg-$default_netdevice");

}

sub test_flags { {fatal => 1} }

1;
