# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate that http addon extension repo added during
# installation is enabled in the installed system.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use repo_tools 'validate_repo_properties';

sub run {
    select_console 'root-console';
    validate_repo_properties({
            Alias => get_required_var('REPO_SLE_PRODUCT_HA'),
            Name => get_required_var('DISTRI') . '-ha',
            URI => 'http://openqa.suse.de/assets/repo/' .
              get_required_var('REPO_SLE_PRODUCT_HA'),
            Enabled => 'Yes',
            Autorefresh => 'On'
    });
}

1;
