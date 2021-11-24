# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Prepare systemd and testsuite.
# Maintainer: Sergio Lindo Mansilla <slindomansilla@suse.com>, Thomas Blume <tblume@suse.com>

use base 'systemd_testsuite_test';
use warnings;
use strict;
use testapi;

sub run {
    my ($self) = @_;
    $self->testsuiteinstall;
    assert_script_run('cd /usr/lib/systemd/tests');
    assert_script_run('./run-tests.sh --prepare', 600);
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
