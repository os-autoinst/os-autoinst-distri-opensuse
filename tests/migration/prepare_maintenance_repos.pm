# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Prepare maintenance updates repos.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;

sub run {
    my @maint_test_repo = ();
    foreach my $addon (split(/,/, get_var('SCC_ADDONS', ''))) {
        push(@maint_test_repo, split(/,/, get_var(uc($addon) . '_TEST_REPOS')));
    }
    set_var('MAINT_TEST_REPO', join(',', @maint_test_repo));
}

1;
