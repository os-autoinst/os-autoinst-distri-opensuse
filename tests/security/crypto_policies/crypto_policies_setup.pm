# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Setup system for crypto-policies testing, basic smoke tests
# Maintainer: QE Security <none@suse.de>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    my ($self) = @_;
    select_serial_terminal;
    zypper_call 'in crypto-policies crypto-policies-scripts';
    validate_script_output('update-crypto-policies --show', sub { m/DEFAULT/ });
    #try to set a fake non existent policy, should give error
    my $msg = script_output('update-crypto-policies --set FOOBAR', proceed_on_failure => 1);
    die unless ($msg =~ m/not found/);
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
