# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Build nested qcow2 image for libvirt and kvm tests, the image
#          can be used in cc tests or other nested virtualization setups.
#          to simply the tests, we need disable firewalld, clean current
#          network udev rule, and permit root ssh.
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#97796

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'permit_root_ssh';
use power_action_utils 'power_action';

sub run {
    my $self = shift;
    select_serial_terminal;

    # Modify the grub timeout to 1 second, then OS can autoboot after reset
    assert_script_run("sed -i 's/GRUB_TIMEOUT=.*\$/GRUB_TIMEOUT=1/' /etc/default/grub");
    assert_script_run("grub2-mkconfig -o /boot/grub2/grub.cfg");

    # Disable the firewalld so that we can access the vm via ssh for later tests
    assert_script_run("systemctl disable firewalld");

    # Clean the network rule file, then the default NIC name can be re-used
    assert_script_run("echo '' > /etc/udev/rules.d/70-persistent-net.rules");

    # Permit ssh login as root
    permit_root_ssh();

    # Power down the vm
    power_action('poweroff');
}

1;
