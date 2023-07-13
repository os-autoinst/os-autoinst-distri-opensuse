# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate that SSH service is enabled on Installation Settings screen
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;
use Test::Assert 'assert_true';

sub run {
    my $installation_settings = $testapi::distri->get_installation_settings();
    assert_true($installation_settings->is_ssh_service_enabled(),
        "SSH service is not enabled, though it is expected to be enabled.");
}

1;
