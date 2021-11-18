# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Open SSH port on Installation Settings Screen and ensure the valid message is shown.
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base 'y2_installbase';
use strict;
use warnings;

sub run {
    my $installation_settings = $testapi::distri->get_installation_settings();
    $installation_settings->open_ssh_port();
}

1;
