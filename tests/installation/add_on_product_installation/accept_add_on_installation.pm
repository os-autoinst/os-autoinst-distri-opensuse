# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Accept current list of Add On Products to install.
#
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_installbase';

sub run {
    $testapi::distri->get_add_on_product_installation()->accept_add_on_products();
}

1;
