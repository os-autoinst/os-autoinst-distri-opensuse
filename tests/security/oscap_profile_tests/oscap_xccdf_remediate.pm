# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Generic test for hardening profile in the 'scap-security-guide': mitigation mode
# Maintainer: QE Security <none@suse.de>

use base 'oscap_tests';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = @_;
    select_console 'root-console';

    $self->oscap_remediate();
}

sub test_flags {
    # Do not rollback as next test module will be run on this test environments
    return {fatal => 0};
}

1;
