# SUSE's openQA tests
#
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Other Desktop Environments: Awesome Window Manager
#          Update the openQA internal configuration after the DE has been installed
# Maintainer: Dominique Leuenberger <dimstar@opensuse.org>

use base "x11test";
use strict;
use warnings;
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
