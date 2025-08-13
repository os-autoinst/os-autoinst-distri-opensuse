# SUSE's openQA tests
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Checks an service after an upgrade
# Maintainer: Joachim Rauch <jrauch@suse.com>

use base 'consoletest';
use testapi;
use utils 'systemctl';
use service_check;
use version_utils qw(is_sle is_sles4sap);
use main_common 'is_desktop';

sub run {
    select_console 'root-console';
    check_services($default_services) if (is_sle && !is_desktop && !is_sles4sap && !get_var('MEDIA_UPGRADE') && !get_var('ZDUP') && !get_var('INSTALLONLY'));

    if ($srv_check_results{'after_migration'} eq 'FAIL') {
        record_info("Summary", "failed", result => 'fail');
        die "Service check after migration failed!";
    }
}

sub test_flags {
    return {fatal => 0};
}

1;
