# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate that addon repos activated during the installation are
# properly added and enabled.
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base 'consoletest';

use strict;
use warnings;

use testapi;
use repo_tools 'validate_repo_properties';

sub run {
    select_console 'root-console';

    for my $addon (split(/,/, get_required_var('ADDONURL'))) {
        my $uc_addon = uc($addon);
        my $uri = get_required_var("ADDONURL_$uc_addon");
        my $alias = get_required_var("REPO_SLE_PRODUCT_$uc_addon");
        my $name = get_required_var("DISTRI") . "-$addon";
        validate_repo_properties({
                Alias => $alias,
                Name => $name,
                URI => $uri,
                Enabled => 'Yes',
                Autorefresh => 'On'
        });
    }
}

1;
