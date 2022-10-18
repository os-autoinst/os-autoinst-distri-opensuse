# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-country
# Summary: yast timezone, list, set and show summary
# - Install yast2-country
# - Check current timezone
# - List available timezones
# - Set timezone to Africa/Cairo
# - Check if timezone was set to Africa/Cairo
# - Return to previous timezone
# Maintainer: Katerina Lorenzova <klorenzova@suse.cz>

use base 'y2_module_basetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    my ($self) = @_;
    select_serial_terminal;
    zypper_call "in yast2-country";
    my $timezone = script_output 'yast timezone summary 2>&1 | grep "Current Time Zone" | cut -d: -f2';
    record_info 'default timezone', $timezone;
    validate_script_output 'yast timezone list 2>&1', sub { m#Africa/Cairo# };
    assert_script_run 'yast timezone set timezone=Africa/Cairo';
    validate_script_output 'yast timezone summary 2>&1', sub { m#Africa/Cairo# };
    assert_script_run "yast timezone set timezone=$timezone";
}
1;
