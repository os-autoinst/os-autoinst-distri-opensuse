# Copyright 2018-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Package: apparmor-utils
# Summary: Enforce a disabled profile with aa-enforce.
# - restarts apparmor
# - disables nscd by running aa-disable /usr/sbin/nscd
# - use aa-status to check if nscd is really disabled
# - runs aa-enforce on /usr/bin/nscd to enforce mode and check output
# - runs aa-status and check if nscd is on enforce mode.
# Maintainer: QE Security <none@suse.de>
# Tags: poo#36877, tc#1621145, poo#81730, tc#1767574

use strict;
use warnings;
use base "apparmortest";
use testapi;
use utils;
use services::apparmor;

sub run {
    my ($self) = @_;
    select_console 'root-console';
    services::apparmor::check_aa_enforce($self);

    # Verify "https://bugs.launchpad.net/apparmor/+bug/1848227"
    $self->test_profile_content_is_special("aa-enforce", "Setting.*to enforce mode");
}

1;
