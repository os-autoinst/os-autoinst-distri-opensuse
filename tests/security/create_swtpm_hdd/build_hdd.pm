# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Ship the "swtpm" software TPM emulator for QEMU,
#          prepare a test image with with grub timeout=1, and
#          root access for ssh is enabled along with udev rules.
#          at the same time, install some required packages.
#
# Maintainer: rfan1 <richard.fan@suse.com>
# Tags: poo#81256, tc#1768671, poo#93835

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils qw(zypper_call permit_root_ssh);
use power_action_utils 'power_action';

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # Install tpm and tpm2 related packages, then we can verify the swtpm function
    zypper_call("in tpm-tools tpm-quote-tools tpm2-0-tss tpm2-tss-engine tpm2.0-abrmd tpm2.0-tools trousers");
    assert_script_run("systemctl enable tcsd");

    # Modify the grub setting with "grub timeout=1"
    assert_script_run("sed -i 's/GRUB_TIMEOUT=.*\$/GRUB_TIMEOUT=1/' /etc/default/grub");
    assert_script_run("grub2-mkconfig -o /boot/grub2/grub.cfg");

    # Disable the firewalld so that we can access the vm via ssh for later tests
    assert_script_run("systemctl disable firewalld");

    # Define a new udev rule file to keep the NIC name persistent across OS rebooting
    my $udev_rule_file = '/etc/udev/rules.d/70-persistent-net.rules';
    my $nic_name       = script_output("ls /etc/sysconfig/network | grep ifcfg- | grep -v lo | awk -F '-' '{print \$2}'");
    assert_script_run("wget --quiet " . data_url("swtpm/70-persistent-net.rules") . " -O $udev_rule_file");
    assert_script_run("sed -i 's/NAME=\"\"/ NAME=\"$nic_name\"/' $udev_rule_file");

    # Permit ssh login as root
    permit_root_ssh();

    # Power down the vm
    power_action('poweroff');
}

1;
