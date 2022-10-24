# SUSE's openQA tests
#
# Copyright 2018-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

#
# Summary: Test 'sestatus/selinuxenabled' commands get the right status of a system running SELinux
# Maintainer: QE Security <none@suse.de>
# Tags: poo#40358, tc#1682592, poo#105202, tc#1769801

use base 'selinuxtest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    my ($self) = @_;
    select_serial_terminal;
    $self->set_sestatus('permissive', 'minimum');

    # Check SELinux status: 'selinuxenabled' exits with status 0 if SELinux is enabled and 1 if it is not enabled
    assert_script_run('selinuxenabled');
}

sub test_flags {
    return {fatal => 1};
}

1;
