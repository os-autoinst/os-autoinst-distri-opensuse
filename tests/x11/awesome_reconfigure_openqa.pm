# SUSE's openQA tests
#
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: awesome
# Summary: Other Desktop Environments: Awesome Window Manager
#          Update the openQA internal configuration after the DE has been installed
# Maintainer: Dominique Leuenberger <dimstar@opensuse.org>

use base "x11test";
use testapi;
use utils;

sub run {
    my $self = shift;

    set_var('DESKTOP', 'awesome');

    # awesome uses lightdm as window manager, which has the user preselected
    set_var('DISPLAYMANAGER', 'lightdm');
    # LightDM has the user in a drop-down preselected; there is no need to type the username
    set_var('DM_NEEDS_USERNAME', 0);

    $self->result('ok');
}

1;
