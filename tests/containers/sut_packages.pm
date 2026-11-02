# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Upload the installed package list for the Investigation tab
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use Utils::Logging 'upload_sut_packages';

sub run {
    select_serial_terminal;
    upload_sut_packages();
}

sub test_flags {
    return {always_run => 1};
}

1;
