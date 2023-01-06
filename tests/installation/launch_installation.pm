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

sub run {
    my $installation_settings = $testapi::distri->get_installation_settings();
    $installation_settings->install();
}

1;
