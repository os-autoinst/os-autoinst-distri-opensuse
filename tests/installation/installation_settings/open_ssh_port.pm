# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Open SSH port on Installation Settings Screen and ensure the valid message is shown.
#
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_installbase';

sub run {
    my $installation_settings = $testapi::distri->get_installation_settings();
    $installation_settings->open_ssh_port();
}

1;
