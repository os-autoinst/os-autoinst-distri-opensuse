# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This test module answers the popup for configuring
#          online repos with no.

# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_installbase';

sub run {
    my $online_repos_popup = $testapi::distri->get_yes_no_popup();
    $online_repos_popup->decline();
}

1;
