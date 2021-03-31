# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary:
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use parent 'y2_installbase';
use strict;
use warnings FATAL => 'all';
use testapi;

sub run {
    my $suggested_partitioning = $testapi::distri->get_suggested_partitioning();
    $suggested_partitioning->select_guided_setup();
}

1;
