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
use warnings;
use base "opensusebasetest";
use testapi;
use utils;
use power_action_utils 'power_action';
use kernel 'remove_kernel_packages';

sub from_repo {
    my ($repo, $pkg) = @_;

    zypper_ar($repo, name => 'change-kernel') if ($repo);
    zypper_call("in --force-resolution --force --replacefiles --repo change-kernel $pkg",
        dumb_term => 1);
}

sub from_rpm {
    my ($uri) = @_;

    assert_script_run("curl --location --output /tmp/kernel.rpm $uri");
    assert_script_run('rpm -i --oldpackage --nosignature --force /tmp/kernel.rpm', 120);
}

sub run {
    my $self = shift;
    my $repo = get_var('CHANGE_KERNEL_REPO');
    my $rpm  = get_var('ASSET_CHANGE_KERNEL_RPM');
    my $pkg  = get_var('CHANGE_KERNEL_PKG') || 'kernel-default';

    $self->wait_boot;
    $self->select_serial_terminal;

    # Avoid conflicts by removing any existing kernels
    remove_kernel_packages();

    # Install the new kernel
    if ($rpm) {
        from_rpm(autoinst_url("/assets/other/$rpm"));
    }
    else {
        from_repo($repo, $pkg);
    }

    # Reboot into the new kernel
    power_action('reboot', textmode => 1);
}

sub test_flags {
    return {fatal => 1};
}

1;
