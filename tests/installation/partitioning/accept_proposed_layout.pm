# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Accept proposed partitioning layout
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use parent 'y2_installbase';
use strict;
use warnings FATAL => 'all';

sub run {
    $testapi::distri->get_suggested_partitioning()->get_suggested_partitioning_page();
    $testapi::distri->get_navigation()->proceed_next_screen();
}

1;
