# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Cleanup scc registration and reregister system and addon products.
# The addons can be defined either by SCC_ADDONS variable or in test data:
#
# test_data:
#   addons: dev,phub
#
# Test data would override SCC_ADDONS.
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

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
