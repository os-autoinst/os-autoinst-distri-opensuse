# Copyright 2017-2018 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Package: PackageKit
# Summary: Prepare system for actual desktop specific updates
# - Disable delta rpms if system is not sle
# - Unmask packagekit service
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
