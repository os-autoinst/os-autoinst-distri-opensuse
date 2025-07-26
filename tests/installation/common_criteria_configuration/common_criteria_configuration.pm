# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: The test module configure the disk encryption password
# when using the Common Criteria role.
# Maintainer: QE Security <none@suse.de>

use parent 'y2_installbase';
use testapi;
use security::config;

sub run {
    my $common_criteria_configuration = $testapi::distri->get_common_criteria_configuration();
    if (check_var('ENCRYPT', '1')) {
        $common_criteria_configuration->configure_encryption($security::config::strong_password);
        $common_criteria_configuration->go_forward();
    } else {
        $common_criteria_configuration->go_forward();
    }
}

1;
