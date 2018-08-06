# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Change the default kernel using a package
# Maintainer: Richard Palethorpe <rpalethorpe@suse.com>
use 5.018;
use base "opensusebasetest";
use testapi;
use utils;
use serial_terminal 'select_virtio_console';
use kernel 'remove_kernel_packages';

sub run {
    my $self = shift;
    my $repo = get_var('CHANGE_KERNEL_REPO');
    my $pkg  = get_var('CHANGE_KERNEL_PKG') || 'kernel-default';

    $self->wait_boot;
    select_virtio_console();

    # Avoid conflicts by removing any existing kernels
    remove_kernel_packages();

    # Install the new kernel
    zypper_ar($repo, 'change-kernel') if ($repo);
    zypper_call("in --force-resolution --force --replacefiles --repo change-kernel $pkg",
        dumb_term => 1);

    # Reboot into the new kernel
    power_action('reboot', textmode => 1);
}

sub test_flags {
    return {fatal => 1};
}

1;
