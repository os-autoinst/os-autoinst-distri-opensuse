# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Add selected additional products
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;

sub run {
    $testapi::distri->get_add_on_product()->add_selected_products();
}

1;
