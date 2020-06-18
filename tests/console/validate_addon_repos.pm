# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Validate that addon repos activated during the installation are
# properly added and enabled.
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base 'consoletest';

use strict;
use warnings;

use testapi;
use repo_tools 'validate_repo_enablement';

sub run {
    select_console 'root-console';

    for my $addon (split(/,/, get_required_var('ADDONURL'))) {
        my $uc_addon = uc($addon);
        my $uri      = get_required_var("ADDONURL_$uc_addon");
        my $alias    = get_required_var("REPO_SLE_PRODUCT_$uc_addon");
        my $name     = get_required_var("DISTRI") . "-$addon";
        validate_repo_enablement(alias => $alias, name => $name, uri => $uri);
    }
}

1;
