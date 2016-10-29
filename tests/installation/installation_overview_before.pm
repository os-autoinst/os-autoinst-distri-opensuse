# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check installation overview before and after any pattern change
# Maintainer: Richard Brown <RBrownCCB@opensuse.org>

use strict;
use warnings;
use base "y2logsstep";
use testapi;

sub run() {
    my ($self) = @_;

    # overview-generation
    # this is almost impossible to check for real
    assert_screen "inst-overview";

    # preserve it for the video
    wait_idle 10;

    $self->check_and_record_dependency_problems;
}

1;
# vim: set sw=4 et:
