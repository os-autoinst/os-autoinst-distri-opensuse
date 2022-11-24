# SUSE's openQA tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Start feature tests before installation
# Maintainer: Martin Kravec <mkravec@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;

sub run {
    assert_screen 'startshell', 150;
}

1;
