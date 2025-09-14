# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: libzypp zypper
# Summary: Ensure the latest versions of libzypp and zypper are
# installed, and confirm that they function as expected
# Maintainer: QE Core <qe-core@suse.de>

use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    select_serial_terminal;
    assert_script_run('zypper ref', timeout => 180);
    # Install latest zypper and libzypp
    zypper_call 'in zypper libzypp';
    assert_script_run('rpm -q zypper libzypp', timeout => 180);

    # Search and Install vim package for zypper verifcation
    zypper_call('se vim');
    zypper_call 'in vim';
}
1;
