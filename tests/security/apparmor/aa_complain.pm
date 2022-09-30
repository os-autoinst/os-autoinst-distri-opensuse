# Copyright 2018-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Package: apparmor-utils apparmor-parser
# Summary: Test AppArmor complain mode.
# - Creates a temporary profile dir in /tmp
# - Sets usr.bin.nscd in complain mode using command
# "aa-complain usr.sbin.nscd" and "aa-complain -d $aa_tmp_prof usr.sbin.nscd",
# validates output of command and take a screenshot of each command
# - Put nscd back in enforce mode
# - Cleanup temporary directories
# Maintainer: QE Security <none@suse.de>
# Tags: poo#36880, tc#1621142, poo#81730, tc#1767574

use strict;
use warnings;
use base "apparmortest";
use testapi;
use utils;
use services::apparmor;

sub run {
    my ($self) = @_;
    select_console 'root-console';
    services::apparmor::check_aa_complain();

    # Verify "https://bugs.launchpad.net/apparmor/+bug/1848227"
    $self->test_profile_content_is_special("aa-complain", "Setting.*to complain mode");
}

1;
