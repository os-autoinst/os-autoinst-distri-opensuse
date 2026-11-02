# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: zypper
# Summary: Ensure zypper can refresh repos and enable them if the install
# medium used was a dvd
# - Enable install dvd
# - Import gpg keys and refresh repositories
# Maintainer: QE Core <qe-core@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(zypper_call zypper_enable_install_dvd);
use version_utils 'is_sle';

sub run {
    select_serial_terminal;

    zypper_enable_install_dvd;
    zypper_call '--gpg-auto-import-keys ref';
    record_info('Test ZYPP_MEDIANETWORK=1');
    assert_script_run 'export ZYPP_MEDIANETWORK=1';
    zypper_call '--gpg-auto-import-keys ref';
    assert_script_run 'unset ZYPP_MEDIANETWORK';
}

sub test_flags {
    return {milestone => 1};
}

1;
