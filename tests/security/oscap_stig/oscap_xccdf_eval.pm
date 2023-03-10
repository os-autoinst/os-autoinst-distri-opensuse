# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test 'stig' hardening in the 'scap-security-guide': detection mode
# Maintainer: QE Security <none@suse.de>
# Tags: poo#93886, poo#104943

use base 'oscap_tests';
use strict;
use warnings;
use testapi;
use utils;
use Utils::Architectures;
use version_utils qw(is_sle);

sub run {
    my ($self) = @_;
    select_console 'root-console';

    # Get ds file and profile ID
    my $f_ssg_ds = is_sle ? $oscap_tests::f_ssg_sle_ds : $oscap_tests::f_ssg_tw_ds;
    my $profile_ID = is_sle ? $oscap_tests::profile_ID_sle_stig : $oscap_tests::profile_ID_tw;
    my $n_passed_rules = 210;
    my $n_failed_rules = 5;
    my @eval_match = (
        'content_rule_is_fips_mode_enabled',
        'content_rule_partition_for_var_log_audit',
        'content_rule_smartcard_pam_enabled',
        'content_rule_grub2_password',
        'content_rule_no_files_unowned_by_user');

    if (is_s390x) {
        $n_passed_rules = 209;
        $n_failed_rules = 5;
    }
    # Exclusion for ARM platform
    if (is_aarch64 or is_arm) {
        @eval_match = (
            'content_rule_is_fips_mode_enabled',
            'content_rule_partition_for_var_log_audit',
            'content_rule_smartcard_pam_enabled',
            'content_rule_grub2_uefi_password',
            'content_rule_no_files_unowned_by_user');
    }

    $self->oscap_evaluate($f_ssg_ds, $profile_ID, $n_passed_rules, $n_failed_rules, \@eval_match);
}

sub test_flags {
    return {always_rollback => 1};
}

1;
