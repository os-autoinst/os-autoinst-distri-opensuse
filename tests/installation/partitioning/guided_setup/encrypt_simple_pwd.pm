# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: The test module configures partition encryption with too
# simple password on Partitioning Scheme Screen of Guided Setup.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use parent 'y2_installbase';
use testapi;

sub run {
    my $partitioning_scheme = $testapi::distri->get_partitioning_scheme();
    $partitioning_scheme->configure_encryption($testapi::password);
    my $fde_enrollment = get_var('FDE_ENROLLMENT');
    $partitioning_scheme->set_fde_enrollment_authentication($fde_enrollment) if $fde_enrollment;
    $partitioning_scheme->go_forward();
    $partitioning_scheme->get_weak_password_warning->press_yes();
}

1;
