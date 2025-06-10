# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: If Full-QR accept current add-on product installation from media,
#          otherwise accept current list of Add On Products to install (screenshots are different).
# Maintainer: QE Security <none@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub run {
    if (check_var('FLAVOR', 'Full-QR') || check_var('FLAVOR', 'Full')) {
        $testapi::distri->get_add_on_product_installation()->accept_add_on_products();
    } else {
        $testapi::distri->get_add_on_product()->accept_current_media_type_selection();
    }
}

1;

