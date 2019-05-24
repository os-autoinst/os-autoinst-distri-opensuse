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

use base "y2_installbase";
use strict;
use warnings;
use testapi;

sub run {
    my ($self) = @_;
    assert_screen('installation-settings-overview-loaded', 250);

    if (check_screen('manual-intervention', 0)) {
        $self->deal_with_dependency_issues;
    }
}

1;
