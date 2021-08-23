# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Register the system with scc in the installer with registration code.
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi 'get_var';

sub run {
    my $reg_code = get_var('SCC_REGCODE');
    $testapi::distri->get_registration()->register_product_with_regcode($reg_code);
    $testapi::distri->get_registration()->enable_update_repositories('The registration server offers update repos.*');
}

1;
