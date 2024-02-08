# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This test module launches the installation from
#          the installation settings page.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base 'y2_installbase';
use Test::Assert 'assert_matches';

sub run {
    my $ntp_settings = $testapi::distri->get_ntp_configuration()->get_ntp_servers();
    assert_matches(qr/suse\.pool\.ntp\.org|10\.160\.0\.45\ 10\.160\.0\.44\ 10\.160\.255\.254|10\.144\.55\.130 10\.144\.55\.131/, $ntp_settings, "NTP setting is not correct");
    $testapi::distri->get_ntp_configuration()->press_next();
}

1;
