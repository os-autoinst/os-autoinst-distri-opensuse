# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Make latest SUT (normally SLES) auto bootable. The first option
#          in grub must be selected automatically witout user intervention
#          This is also the place to add a second NIC if needed in the future.
#
# Maintainer: Jose Lausuch <jalausuch@suse.de>

use base 'opensusebasetest';
use strict;
use testapi;

sub run {
    my ($self) = @_;

    $self->select_serial_terminal;

    assert_script_run('sed -i s/GRUB_TIMEOUT=-1/GRUB_TIMEOUT=0/ /etc/default/grub');
    assert_script_run('grub2-mkconfig -o /boot/grub2/grub.cfg');

    assert_script_run('cp /etc/sysconfig/network/ifcfg-eth0 /etc/sysconfig/network/ifcfg-eth1');

    # this is needed for the test 'sle15_workarounds' to work as it fails
    # if the previous test has selected virtio console
    select_console('root-console');
}

1;
