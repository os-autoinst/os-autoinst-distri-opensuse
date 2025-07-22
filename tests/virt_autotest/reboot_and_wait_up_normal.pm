# SUSE's openQA tests
#
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: virt_autotest: virtualization automation test in openqa, both kvm and xen supported
# Maintainer: alice <xlai@suse.com>

use testapi;
use Utils::Architectures;
use base "reboot_and_wait_up";
use virt_utils 'is_installed_equal_upgrade_major_release';
use Utils::Backends 'is_remote_backend';
use ipmi_backend_utils;

sub run {
    my $self = shift;
    my $timeout = 180;

    #online upgrade actually
    return if (is_remote_backend && is_aarch64 && (is_installed_equal_upgrade_major_release || get_var("VIRT_PRJ1_GUEST_INSTALL") || get_var("VIRT_PRJ4_GUEST_UPGRADE")));
    $self->reboot_and_wait_up($timeout);
}

sub test_flags {
    return {fatal => 1};
}

1;

