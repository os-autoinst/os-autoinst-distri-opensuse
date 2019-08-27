# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Make sure apparmor is installed and running for later testing by
# installing apparmor pattern.
# - installs apparmor pattern
# - starts apparmor service
# Maintainer: Juraj Hura <jhura@suse.com>

use base "basetest";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';
use services::apparmor;

sub run {
    select_console 'root-console';
    zypper_call 'in -t pattern apparmor';
    services::apparmor::start_service;
    services::apparmor::enable_service;
}

sub test_flags {
    return {milestone => 1};
}

1;
