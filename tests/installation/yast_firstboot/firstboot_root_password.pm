# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Handles Root Password dialog in YaST Firstboot Configuration
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base 'y2_firstboot_basetest';
use strict;
use warnings;

sub run {
    my $auth_for_root = $testapi::distri->get_authentication_for_root();
    $auth_for_root->add_authentication_using_simple_password(
        {password => $testapi::password});
}

1;
