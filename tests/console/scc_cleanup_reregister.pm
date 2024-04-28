# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Cleanup scc registration and reregister system and addon products.
# The addons can be defined by SCC_ADDONS variable.
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
use migration 'deregister_dropped_modules';
use testapi;
use registration qw(cleanup_registration register_product register_addons_cmd);

sub run {
    select_console 'root-console';
    cleanup_registration;
    register_product;
    register_addons_cmd();
    deregister_dropped_modules;
}

1;
