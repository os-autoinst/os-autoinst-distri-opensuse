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

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(zypper_call zypper_enable_install_dvd);
use version_utils 'is_sle';

sub run {
    my $self = shift;
    select_serial_terminal;

    zypper_enable_install_dvd;
    zypper_call '--gpg-auto-import-keys ref';
}

sub test_flags {
    return {milestone => 1};
}

1;
