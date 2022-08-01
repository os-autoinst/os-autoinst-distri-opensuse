# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Add selected additional products
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base 'y2_installbase';
use strict;
use warnings;

sub run {
    $testapi::distri->get_product_selection()->add_selected_products();
}

1;
