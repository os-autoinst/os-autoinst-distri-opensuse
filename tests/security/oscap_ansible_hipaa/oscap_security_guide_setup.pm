# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test 'pci-dss-4' hardening in the 'scap-security-guide' works: setup environment
# Maintainer: QE Security <none@suse.de>
# Tags: poo#93886, poo#104943

use base 'oscap_tests';
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle);

sub run {
    my ($self) = @_;
    $oscap_tests::sle_version = 'sle' . get_required_var('VERSION') =~ s/([0-9]+).*/$1/r;
    $oscap_tests::evaluate_count = 3;
    $oscap_tests::ansible_remediation = 1;
    $oscap_tests::profile_ID = is_sle ? $oscap_tests::profile_ID_sle_hipaa : $oscap_tests::profile_ID_tw;
    $oscap_tests::ansible_profile_ID = is_sle ? $oscap_tests::sle_version . $oscap_tests::ansible_playbook_sle_hipaa : $oscap_tests::ansible_playbook_standart;

    select_console 'root-console';

    $self->oscap_security_guide_setup();
}

sub test_flags {
    return {fatal => 1};
}

1;
