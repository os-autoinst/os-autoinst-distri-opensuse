# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Prepare dracut and testsuite.
# Maintainer: dracut maintainers <dracut-maintainers@suse.de>

use base 'dracut_testsuite_test';
use warnings;
use strict;
use testapi;

sub run {
    my ($self) = @_;
    $self->testsuiteinstall;
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
