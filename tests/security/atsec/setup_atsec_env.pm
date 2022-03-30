# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Download the test scripts which Atsec tests need
# Maintainer: xiaojing.liu <xiaojing.liu@suse.com>
# Tags: poo#108485

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = shift;

    select_console 'root-console';

    # Install tool packages
    zypper_call('in wget');

    # Download the test scripts
    my $code_path = get_required_var('CODE_PATH');
    my @lines = split(/[\/\.]+/, $code_path);
    my $file_name = $lines[-2];
    my $file_tar = $file_name . 'tar';
    assert_script_run("wget --no-check-certificate $code_path -O /tmp/$file_tar");
    assert_script_run("tar -xvf /tmp/$file_tar -C /tmp/");
    assert_script_run("mv /tmp/$file_name /usr/local/atsec");
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
