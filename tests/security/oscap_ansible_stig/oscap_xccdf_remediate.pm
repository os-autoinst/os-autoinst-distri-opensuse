# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test 'stig' hardening in the 'scap-security-guide': ansible mitigation mode
# Maintainer: QE Security <none@suse.de>
# Tags:

use base 'oscap_tests';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = @_;

    $self->oscap_remediate();
}

sub test_flags {
    # Do not rollback as next test module will be run on this test environments
    return {fatal => 0};

}

1;
