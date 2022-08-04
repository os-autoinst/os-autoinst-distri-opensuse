# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: sle-module-live-patching SLE-Module-Live-Patching sle-live-patching SLE-Live-Patching
# Summary: This module installs the kernel livepatching product and
#          verifies the installation.
# Maintainer: Nicolai Stange <nstange@suse.de>

use 5.018;
use warnings;
use strict;
use base 'opensusebasetest';
use testapi;
use utils;
use klp;
use power_action_utils 'power_action';
use Utils::Architectures;
use Utils::Backends qw(is_pvm);

sub do_reboot {
    my $self = shift;

    power_action('reboot', textmode => 1, keepconsole => is_pvm);
    reconnect_mgmt_console if is_pvm;
    $self->wait_boot;
    $self->select_serial_terminal;
}

sub run {
    my $self = shift;
    my $kver;
    my $kflavor;

    # Running in the same job as qa_test_klp, reboot to fix kernel state
    if (get_var('QA_TEST_KLP_REPO')) {
        $self->do_reboot;
    }

    my $output = script_output('uname -r');
    if ($output =~ /^([0-9]+([-.][0-9a-z]+)*)-([a-z][a-z0-9]*)/i) {
        $kver = $1;
        $kflavor = $3;
    }
    else {
        die "Failed to parse 'uname -r' output: '$output'";
    }

    unless (get_var('KGRAFT')) {
        zypper_call('ref');
        install_klp_product();
    }

    my $klp_pkg = find_installed_klp_pkg($kver, $kflavor);
    if (!$klp_pkg) {
        die "No installed kernel livepatch package for current kernel found";
    }

    verify_klp_pkg_patch_is_active($klp_pkg);
    verify_klp_pkg_installation($klp_pkg);

    # Reboot and check that the livepatch gets loaded again.
    $self->do_reboot;
    verify_klp_pkg_patch_is_active($klp_pkg);
}

sub test_flags {
    return {fatal => 1};
}

1;
