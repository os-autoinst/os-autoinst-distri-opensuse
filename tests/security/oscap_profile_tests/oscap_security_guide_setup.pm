# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Generic test for hardening profile in the 'scap-security-guide': setup environment
# Maintainer: QE Security <none@suse.de>

use Mojo::Base 'oscap_tests';
use testapi;
use utils;
use version_utils qw(is_sle);
use registration qw(add_suseconnect_product);

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
    if (get_var('OSCAP_UPLOAD_DEBUG_LOGS')) {
        $oscap_tests::oscap_upload_debug_logs = get_var('OSCAP_UPLOAD_DEBUG_LOGS');
    }

    # Ugly, but we need the development tools repo in order to satisfy
    # package requirements of oscap_security_guide_setup.
    # Particularly: ninja
    if (is_sle('<16')) {
        add_suseconnect_product('sle-module-desktop-applications');
        add_suseconnect_product('sle-module-development-tools');
    }

    $self->oscap_security_guide_setup();
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
