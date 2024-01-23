# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Generic test for hardening profile in the 'scap-security-guide': setup environment
# Maintainer: QE Security <none@suse.de>

use base 'oscap_tests';
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle);

sub run {
    my ($self) = @_;
    select_console 'root-console';

    $oscap_tests::sle_version = 'sle' . get_required_var('VERSION') =~ s/([0-9]+).*/$1/r;
    $oscap_tests::evaluate_count = get_required_var('OSCAP_EVAL_COUNT');
    $oscap_tests::profile_ID = is_sle ? get_required_var('OSCAP_PROFILE_ID') : $oscap_tests::profile_ID_tw;
    if (get_required_var('OSCAP_ANSIBLE_REMEDIATION')) {
        $oscap_tests::ansible_remediation = get_required_var('OSCAP_ANSIBLE_REMEDIATION');
        $oscap_tests::ansible_profile_ID = is_sle ? $oscap_tests::sle_version . '-' . get_required_var('OSCAP_ANSIBLE_PROFILE_ID') : $oscap_tests::ansible_playbook_standart;
    }

    $self->oscap_security_guide_setup();
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
