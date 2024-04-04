# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: The test module configure the disk encryption password
# when using the Common Criteria role.
# Maintainer: QE Security <none@suse.de>

use parent 'y2_installbase';
use strict;
use warnings;

sub run {
    my $common_criteria_configuration = $testapi::distri->get_common_criteria_configuration();
    $common_criteria_configuration->configure_encryption($testapi::password);
    $common_criteria_configuration->go_forward();
    $common_criteria_configuration->get_weak_password_warning->press_yes();
}

1;
