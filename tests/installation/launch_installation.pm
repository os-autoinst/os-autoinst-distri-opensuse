# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This test module launches the installation from
#          the installation settings page.

# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_installbase';

sub run {
    my $installation_settings = $testapi::distri->get_installation_settings();
    $installation_settings->install();
}

1;
