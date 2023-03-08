# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Test module to select a product to install
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use testapi 'get_var';
use strict;
use warnings;

sub run {
    my $product_selection = $testapi::distri->get_product_selection();

    $product_selection->wait_product_selection_page({timeout_scale => get_var('TIMEOUT_SCALE', 1), message => 'Product Selection page is not displayed'});
    $product_selection->install_product('SLES');
}

1;
