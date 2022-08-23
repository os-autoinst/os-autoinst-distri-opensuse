# SUSE's openQA tests
#
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Other Desktop Environments: LXQt
#          Update the openQA internal configuration after the DE has been installed
# Maintainer: Dominique Leuenberger <dimstar@opensuse.org>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $self = shift;

    set_var("DESKTOP", "lxqt");

    # LXQt uses sddm as window manager, which has the user preselected
    set_var('DISPLAYMANAGER', 'sddm');
    # sddm asks straoght for PW with only one user; there is no need to type the username
    set_var('DM_NEEDS_USERNAME', 0);

    $self->result('ok');
}

1;
