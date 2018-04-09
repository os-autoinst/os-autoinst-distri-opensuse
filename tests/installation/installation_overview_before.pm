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

sub run {
    my ($self) = @_;

    # overview-generation
    # this is almost impossible to check for real
    # See poo#12322. Prevent checks before overview is fully loaded
    # 'inst-overview' needle is used in many places and sometimes includes only
    # parts which are there while overview is still loading. This check has to be
    # performed only once, as state of buttons can be different
    assert_screen('installation-settings-overview-loaded', 90);

    if (check_screen('manual-intervention', 0)) {
        $self->deal_with_dependency_issues;
    }
}

1;
