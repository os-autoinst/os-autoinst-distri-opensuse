# XEN regression tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Wait for guests so they finish the installation
# Maintainer: Jan Baier <jbaier@suse.cz>

use base 'xen';

use strict;
use warnings;
use testapi;
use utils;

sub run {
    zypper_call '-t in nmap iputils bind-utils virt-manager';

    # Fill the current pairs of hostname & address into /etc/hosts file
    assert_script_run "echo '$xen::guests{$_}->{ip} $_' >> /etc/hosts" foreach (keys %xen::guests);
    assert_script_run "cat /etc/hosts";

    # Check if SSH is open because of that means that the guest is installed
    script_retry("nmap $_ -PN -p ssh | grep open", delay => 60, retry => 60) foreach (keys %xen::guests);

    # All guests should be now installed, show them
    assert_script_run 'virsh list --all';
    wait_still_screen 1;
}

1;
