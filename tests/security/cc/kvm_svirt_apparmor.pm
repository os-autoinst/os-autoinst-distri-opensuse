# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'kvm_svirt_apparmor' test case of 'audit-test' test suite
# Maintainer: QE Security <none@suse.de>
# Tags: poo#101761

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use Mojo::File 'path';
use audit_test qw(prepare_for_test parse_kvm_svirt_apparmor_results);

sub run {
    my ($self) = shift;

    select_console 'root-console';

    # The steps of testing kvm_svirt_apparmor is not same as other audit-test,
    # so we need to do the `make` in the test case directory and run the test.
    prepare_for_test();

    assert_script_run('cd kvm_svirt_apparmor/');

    # prepare_for test did the `export MODE=64`, that will make this make fail in aarch64
    script_run('unset MODE');
    assert_script_run('make');
    assert_script_run('cd tests/');
    assert_script_run('./vm-sep');

    my $result = parse_kvm_svirt_apparmor_results('kvm_svirt_apparmor');
    $self->result($result);
}

1;
