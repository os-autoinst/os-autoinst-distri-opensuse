# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test 'anssi_bp_28_high' hardening in the 'scap-security-guide': detection mode with remote
# Maintainer: QE Security <none@suse.de>
# Tags: poo#93886, poo#104943

use base 'oscap_tests';
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle);

sub run {
    my ($self) = @_;
    select_console 'root-console';

    $self->oscap_evaluate_remote();
}

sub test_flags {
    return {fatal => 0};
}

1;
