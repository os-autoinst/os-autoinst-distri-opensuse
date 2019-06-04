# SUSE's openQA tests
#
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: virt_autotest: virtualization automation test in openqa, both kvm and xen supported
# Maintainer: alice <xlai@suse.com>

use strict;
use warnings;
use testapi;
use base "reboot_and_wait_up";
use virt_utils 'is_installed_equal_upgrade_major_release';
use Utils::Backends 'is_remote_backend';
use ipmi_backend_utils;

sub run {
    my $self    = shift;
    my $timeout = 180;

    #online upgrade actually
    return if (is_remote_backend && check_var('ARCH', 'aarch64') && is_installed_equal_upgrade_major_release);
    $self->reboot_and_wait_up($timeout);
}

sub test_flags {
    return {fatal => 1};
}

1;

