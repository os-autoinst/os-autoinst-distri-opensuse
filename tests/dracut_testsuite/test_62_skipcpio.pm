# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run upstream test TEST-62-SKIPCPIO after applying SUSE patches.
# Maintainer: dracut maintainers <dracut-maintainers@suse.de>

use base "dracut_testsuite_test";
use warnings;
use strict;
use testapi;

sub run {
    my ($self) = @_;
    $self->testsuiterun('TEST-62-SKIPCPIO');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
