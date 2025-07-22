# SUSE's openQA tests
#
# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: gnuhealth stack installation
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'x11test';
use testapi;

sub run {
    my ($self) = @_;
    select_console 'x11';
    ensure_installed 'gnuhealth', timeout => 300;
}

sub test_flags {
    return {fatal => 1};
}

1;
