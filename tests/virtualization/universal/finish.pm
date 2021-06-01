# XEN regression tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Package: libvirt-client iputils nmap xen-tools
# Summary: The last test of a typical virtualization run:
#   It's purpose is to collect logs.
# Maintainer: Pavel Dostal <pdostal@suse.cz>

use base 'consoletest';
use virt_autotest::common;
use virt_autotest::utils;
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $self = shift;
    # Switch to root console to prevent test issues from the desktop environment
    # See https://progress.opensuse.org/issues/93204
    select_console('root-console');
    $self->select_serial_terminal;

    # Show all guests
    assert_script_run 'virsh list --all';
    script_run 'history -a';

    collect_virt_system_logs();
}

1;
