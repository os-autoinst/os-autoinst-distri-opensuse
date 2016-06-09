# SUSE's openQA tests
#
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "x11test";
use strict;
use testapi;
use utils;

sub run() {
    my $self = shift;

    # Next time we boot we are no longer minimalx based, but mate based
    set_var('DESKTOP', 'mate');

    # mate uses lightdm as window manager, which has the user preselected
    set_var('DISPLAYMANAGER',    'lightdm');
    set_var('DM_NEEDS_USERNAME', 0);

    $self->result('ok');
}

1;
# vim: set sw=4 et:
