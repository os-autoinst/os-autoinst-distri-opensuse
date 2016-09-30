# SUSE's openQA tests
#
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Other Desktop Environments: LXQt
# G-Maintainer: Dominique Leuenberger <dimstar@opensuse.org>

use base "x11test";
use strict;
use testapi;
use utils;

sub run() {
    my $self = shift;

    set_var("DESKTOP", "lxqt");

    $self->result('ok');
}

1;
# vim: set sw=4 et:
