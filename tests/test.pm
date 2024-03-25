# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: test
# Summary: test
# Maintainer: QE Core <qe-core@suse.de>

use base 'consoletest';
use testapi;
use strict;
use warnings;

sub run {
    assert_screen();
}

1;
