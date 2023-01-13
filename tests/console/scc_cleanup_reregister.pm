# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Cleanup scc registration and reregister system and addon products.
# The addons can be defined either by SCC_ADDONS variable or in test data:
#
# test_data:
#   addons: dev,phub
#
# Test data would override SCC_ADDONS.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use registration qw(cleanup_registration register_product register_addons_cmd);
use scheduler 'get_test_suite_data';

sub run {
    select_console 'root-console';
    cleanup_registration;
    register_product;
    my $addons = get_test_suite_data()->{addons};
    register_addons_cmd($addons);
}

1;
