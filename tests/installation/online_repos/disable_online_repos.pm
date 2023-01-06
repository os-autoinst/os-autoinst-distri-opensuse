# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This test module answers the popup for configuring
#          online repos with no.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base 'y2_installbase';

sub run {
    my $online_repos_popup = $testapi::distri->get_yes_no_popup_controller();
    $online_repos_popup->decline();
}

1;
