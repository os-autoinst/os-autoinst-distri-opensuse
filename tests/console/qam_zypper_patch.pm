# Copyright 2015-2016 LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: zypper patch for maintenance
# Maintainer: Ludwig Nussel <ludwig.nussel@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console 'root-console';

    zypper_call('in -l -t patch ' . get_var('INCIDENT_PATCH'), exitcode => [0, 102, 103], timeout => 1400);
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
