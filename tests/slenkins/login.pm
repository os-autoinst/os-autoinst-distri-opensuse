# Copyright 2015-2018 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: slenkins tests login
# Maintainer: Vladimir Nadvornik <nadvornik@suse.cz>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

