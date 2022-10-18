# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-country
# Summary: yast language test
# List languages, set default and secondary languages
# Maintainer: Michael Grifalconi <mgrifalconi@suse.com>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    my $self = shift;
    select_serial_terminal;
    zypper_call "in yast2-country";
    validate_script_output 'yast language list', sub { m/(.*)de_DE(.*)it_IT(.*)/s };
    assert_script_run 'yast language set lang=de_DE languages=it_IT';
    validate_script_output 'yast language summary', sub { m/(.*)de_DE(.*)it_IT(.*)/s };
    assert_script_run 'yast language set lang=en_US';
}

1;
