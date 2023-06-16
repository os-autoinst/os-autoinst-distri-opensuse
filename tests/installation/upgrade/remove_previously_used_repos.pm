# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles page for detection of previously used repositories.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;

sub run {
    my $previous_repo = $testapi::distri->get_previously_used_repos();
    $previous_repo->get_previously_used_repos();
    $previous_repo->press_next();
}

1;
