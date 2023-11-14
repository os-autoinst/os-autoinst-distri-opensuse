# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test 'anssi_bp_28_high' hardening in the 'scap-security-guide': detection mode
# Maintainer: QE Security <none@suse.de>
# Tags: poo#93886, poo#104943

use base 'oscap_tests';
use strict;
use warnings;
use testapi;
use utils;
use Utils::Architectures;

sub run {
    my ($self) = @_;
    select_console 'root-console';

    # Set expected results
    my @eval_match = ('');

    $self->oscap_evaluate(\@eval_match);
}

sub test_flags {
    return {fatal => 0};
}

1;
