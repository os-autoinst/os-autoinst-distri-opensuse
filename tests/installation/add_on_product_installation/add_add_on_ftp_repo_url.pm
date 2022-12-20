# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Add a new add-on specifying repo URL, in particular FTP URL for Live Patching.
# Pre-requisite: one or more add-owns has been added before this one.
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi 'get_var';

sub run {
    my $url = 'ftp://openqa.suse.de/' . get_var('REPO_SLE_MODULE_LIVE_PATCHING');
    $testapi::distri->get_add_on_product_installation()->add_add_on_product();
    $testapi::distri->get_add_on_product()->accept_current_media_type_selection();
    $testapi::distri->get_repository_url()->add_repo({url => $url});
}

1;
