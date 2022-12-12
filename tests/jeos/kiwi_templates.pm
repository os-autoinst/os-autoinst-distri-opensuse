# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Install kiwi templates for JeOS
# Maintainer: QA-C <qa-c@suse.de>

use Mojo::Base qw(opensusebasetest);
use testapi;
use version_utils qw(is_sle is_leap);
use utils qw(zypper_call);
use serial_terminal qw(select_serial_terminal);

sub run {
    select_serial_terminal;

    my $rpm;
    if (is_sle('<15-SP2')) {
        $rpm = 'kiwi-templates-SLES15-JeOS';
    } elsif (is_leap('<=15.4') || is_sle('<15-SP4')) {
        $rpm = 'kiwi-templates-JeOS';
    } else {
        $rpm = 'kiwi-templates-Minimal';
    }

    zypper_call "in $rpm";
    assert_script_run "rpm -ql $rpm";
}

1;
