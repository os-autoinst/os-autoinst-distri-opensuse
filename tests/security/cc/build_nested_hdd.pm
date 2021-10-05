# Copyright 2021 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.
#
# Summary: Build nested qcow2 image for libvirt and kvm tests, the image
#          can be used in cc tests or other nested virtualization setups.
#          to simply the tests, we need disable firewalld, clean current
#          network udev rule, and permit root ssh.
#
# Maintainer: rfan1 <richard.fan@suse.com>
# Tags: poo#97796

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils 'permit_root_ssh';
use power_action_utils 'power_action';

sub run {
    my $self = shift;
    $self->select_serial_terminal;

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
