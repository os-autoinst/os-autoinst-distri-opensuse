# SUSE's openQA tests
#
# Copyright 2016-2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test rolling back to original system version after
#          migration, using transactional-update rollback.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use testapi;
use utils;
use strict;
use warnings;
use power_action_utils 'power_action';
use Utils::Backends 'is_remote_backend';
use version_utils 'verify_os_version';

sub reboot {
    my ($self) = @_;
    power_action('reboot', textmode => 1, keepconsole => 1);
    reconnect_mgmt_console if is_remote_backend;
    $self->wait_boot(ready_time => 300, bootloader_time => 300);
}
sub run {
    my ($self) = @_;
    $self->reboot;
    select_console 'root-console';
    verify_os_version;
    script_run("transactional-update rollback last");
    $self->reboot;
    select_console 'root-console';
    my $rollback_version = get_var("FROM_VERSION");
    verify_os_version($rollback_version);
}

sub test_flags {
    return {fatal => 1};
}

1;
