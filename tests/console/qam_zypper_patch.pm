# Copyright 2015-2024 LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: zypper patch for maintenance
# Maintainer: Ludwig Nussel <ludwig.nussel@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;

    # NVIDIA repo needs new signing key, see poo#163094
    my $sign_key = get_var('BUILD') =~ /openSUSE-repos/ ? '--gpg-auto-import-keys' : '';
    zypper_call("$sign_key in -l -t patch " . get_var('INCIDENT_PATCH'), exitcode => [0, 102, 103], timeout => 1400);
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
