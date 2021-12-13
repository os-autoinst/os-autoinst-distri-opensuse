# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Wait for the installation to be finished.
# Use TIMEOUT_SCALE so expected installation time can be adjusted
# for slower architectures.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use strict;
use warnings;
use base 'y2_installbase';
use testapi 'get_var';

sub run {
    # Estimated timeout of 5500 seconds (we need to fix the client in order
    # to introduce here the right value, because of that we set the half of it)
    my $timeout = 2750 * get_var('TIMEOUT_SCALE', 1);
    $testapi::distri->get_performing_installation()->perform($timeout);
}

1;
