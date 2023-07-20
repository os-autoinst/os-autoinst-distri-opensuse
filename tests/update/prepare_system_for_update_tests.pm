# Copyright 2017-2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Package: PackageKit
# Summary: Prepare system for actual desktop specific updates
# - Disable delta rpms if system is not sle
# - Unmask packagekit service
# - Mask purge-kernels service, see poo#133016
# - Run "pkcon refresh"
# Maintainer: Stephan Kulow <coolo@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';

sub run {
    select_console 'root-console';
    ensure_serialdev_permissions;
    # default is true, for legacy reasons we were running this on openSUSE only
    assert_script_run "echo \"download.use_deltarpm = false\" >> /etc/zypp/zypp.conf" if !is_sle;
    systemctl 'unmask packagekit';
    systemctl 'mask purge-kernels';

    assert_script_run "pkcon refresh", 400;
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    $self->upload_packagekit_logs;
}

1;
