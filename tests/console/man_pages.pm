# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: man-pages
# Summary: Basic functional test for man-pages
# Maintainer: QE Core <qe-core@suse.de>

use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use package_utils 'install_package';

sub run {
    my ($self) = @_;
    select_serial_terminal;

    install_package('man-pages man', trup_reboot => 1);
    assert_script_run 'man --version';
    assert_script_run 'man man > man_man.txt';
    assert_script_run 'grep -q "Manual pager utils" man_man.txt';
}

1;
