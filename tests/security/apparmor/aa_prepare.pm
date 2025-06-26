# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: patterns-base-apparmor apparmor-parser
# Summary: Make sure apparmor is installed and running for later testing by
# installing apparmor pattern.
# - installs apparmor pattern
# - starts apparmor service
# Maintainer: QE Security <none@suse.de>

use base "basetest";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';
use version_utils qw(is_jeos);
use services::apparmor;
use serial_terminal qw(select_serial_terminal);

sub run {
    select_serial_terminal;
    zypper_call 'in -t pattern apparmor';
    if (is_jeos) {
        record_info 'JeOS', 'Some packages needed by the tests are not pre-installed by default in JeOS.';
        zypper_call('in apparmor-utils samba screen netpbm');
    }
    services::apparmor::start_service;
    services::apparmor::enable_service;
}

sub test_flags {
    return {milestone => 1};
}

1;
