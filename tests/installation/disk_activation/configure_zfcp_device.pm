# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This test module handles ZFCP disk activation
#          through libyui-rest-client.

# Maintainer: QE YaST <qa-sle-yast@suse.de>

use strict;
use warnings;
use base 'y2_installbase';
use testapi;

sub run {
    my $add_new_zfcp_device = $testapi::distri->get_add_new_zfcp_device();
    # configure first device
    $add_new_zfcp_device->configure({channel => '0.0.fa00'});
    save_screenshot;
    # press "Add" button to add another device
    $testapi::distri->get_configured_zfcp_devices()->add();
    # configure second device
    $add_new_zfcp_device->configure({channel => '0.0.fc00'});
}

1;
