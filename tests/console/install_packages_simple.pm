# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Basic installation of packages, using zypper. Packages
# defined in test_data. Example:
#
# test_data:
#   install_packages:
#     - apache2
#     - krb5
#
# In case of installation failure, the test will die.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use base 'consoletest';
use warnings;
use testapi;
use utils 'zypper_call';
use scheduler 'get_test_suite_data';

sub run {
    my $packages = get_test_suite_data()->{install_packages};
    select_console 'root-console';
    zypper_call 'in ' . join(' ', @{$packages});
}

sub test_flags {
    return {fatal => 1};
}

1;
