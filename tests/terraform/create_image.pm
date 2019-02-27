# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Create HDD image that boots automatically and add a second
#          interface config file.
# Maintainer: Jose Lausuch <jalausuch@suse.com>


use base 'opensusebasetest';
use strict;
use testapi;
use warnings;
use version_utils qw(is_sle is_tumbleweed is_leap);

sub run {
    my ($self) = @_;

    select_console('root-console');

    # Don't wait for user to press enter, boot the system automatically
    assert_script_run('sed -i s/GRUB_TIMEOUT=-1/GRUB_TIMEOUT=0/ /etc/default/grub');
    assert_script_run('grub2-mkconfig -o /boot/grub2/grub.cfg');

    # Allow having a second NIC configurable
    if (is_sle || is_leap) {
        assert_script_run('cp /etc/sysconfig/network/ifcfg-eth0 /etc/sysconfig/network/ifcfg-eth1');
        # Force eth0 as main NIC at first boot
        assert_script_run('rm /etc/udev/rules.d/70-persistent-net.rules');
    }
    if (is_tumbleweed) {
        assert_script_run('cp /etc/sysconfig/network/ifcfg-ens4 /etc/sysconfig/network/ifcfg-ens3');
    }

    # Allow any connection to the VM (e.g. ICMP, SSH, ...)
    systemctl("disable firewalld");
    systemctl("disable apparmor");
}

1;
