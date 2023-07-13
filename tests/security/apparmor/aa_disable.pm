# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test AppArmor aa-disable - disable an AppArmor security profile.
# Maintainer: QE Security <none@suse.de>
# Tags: poo#81730, tc#1767574

use strict;
use warnings;
use base "apparmortest";
use testapi;
use utils;

sub run {
    my ($self) = @_;
    select_console 'root-console';

    $self->test_profile_content_is_special("aa-disable", "Disabling.*");
}

1;
