# SUSE's openQA tests
#
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Other Desktop Environments: Mate
# Maintainer: Dominique Leuenberger <dimstar@opensuse.org>

use base "x11test";
use testapi;
use utils;

sub run {
    my $self = shift;

    # Next time we boot we are no longer minimalx based, but mate based
    set_var('DESKTOP', 'mate');

    # mate uses lightdm as window manager, which has the user preselected
    set_var('DISPLAYMANAGER', 'lightdm');
    set_var('DM_NEEDS_USERNAME', 0);

    $self->result('ok');
}

1;
