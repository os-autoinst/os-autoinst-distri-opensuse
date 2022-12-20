# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Add a new add-on specifying repo URL, in particular HTTP URL for HA.
# Pre-requisite: no more add-owns has been added before this one.
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi 'get_var';

sub run {
    my $url = 'http://openqa.suse.de/assets/repo/' . get_var('REPO_SLE_PRODUCT_HA');
    $testapi::distri->get_add_on_product()->confirm_like_additional_add_on();
    $testapi::distri->get_add_on_product()->accept_current_media_type_selection();
    $testapi::distri->get_repository_url()->add_repo({url => $url});
}

1;
