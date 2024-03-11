# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: make sure that FIPS is enabled
# Maintainer: QE Security <none@suse.de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    my ($self) = @_;

    select_serial_terminal;

    assert_script_run q(grep '^1$' /proc/sys/crypto/fips_enabled);
}

1;
