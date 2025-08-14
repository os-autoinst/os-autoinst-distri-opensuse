# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Download the test scripts which EAL4 tests need
# Maintainer: QE Security <none@suse.de>
# Tags: poo#108485

use base 'consoletest';
use testapi;
use utils;
use eal4_test;
use serial_terminal 'select_serial_terminal';

sub run {
    my ($self) = shift;

    select_serial_terminal;

    zypper_call('in wget gcc make curl');

    my $code_path = get_required_var('CODE_PATH');
    my ($file_name) = $code_path =~ m|/([^/]+)\.tar$|;

    my $file_tar = $file_name . '.tar';
    assert_script_run("wget --no-check-certificate $code_path -O /tmp/$file_tar");
    assert_script_run("tar -xvf /tmp/$file_tar -C /tmp/");
    assert_script_run("mv /tmp/$file_name $eal4_test::code_dir");
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
