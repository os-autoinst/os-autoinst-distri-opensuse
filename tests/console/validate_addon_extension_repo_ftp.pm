# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate that ftp addon extension repo added during
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
            Alias => get_required_var('REPO_SLE_MODULE_LIVE_PATCHING'),
            Name => get_required_var('DISTRI') . '-module-live-patching',
            URI => 'ftp://openqa.suse.de/' .
              get_required_var('REPO_SLE_MODULE_LIVE_PATCHING'),
            Enabled => 'Yes',
            Autorefresh => 'On'
    });
}

1;
