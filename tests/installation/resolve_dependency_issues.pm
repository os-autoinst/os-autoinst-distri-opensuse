# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Unified dependency issues resolver
# Maintainer: Yiannis Bonatakis <ybonatakis@suse.com>

use strict;
use warnings;
use base "y2logsstep";
use testapi;

sub run {
    my ($self) = @_;
    assert_screen('installation-settings-overview-loaded', 250);
    if (check_screen('dependency-issue', 0) && get_var("WORKAROUND_DEPS")) {
        $self->workaround_dependency_issues;
    }
    if (check_screen('dependency-issue', 0) && get_var("BREAK_DEPS")) {
        $self->break_dependency;
    }
    if (check_screen('manual-intervention', 0)) {
        $self->deal_with_dependency_issues;
    }
}

1;
