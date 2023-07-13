# SUSE's openQA tests
#
# Copyright 2017-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run simple checks after installation
# Maintainer: Martin Kravec <mkravec@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub run_rcshell_checks {
    # Check that system is using UTC timezone
    assert_script_run 'date +"%Z" | grep -x UTC';
}

sub run_common_checks {
    # bsc#1019652 - Check that snapper is configured
    assert_script_run "snapper list";

    # Subvolume check - https://build.opensuse.org/request/show/583954
    assert_script_run "btrfs subvolume show /var";
}

sub run_microos_checks {
    # Should not include kubernetes
    if (check_var('SYSTEM_ROLE', 'microos')) {
        zypper_call 'se -i kubernetes', exitcode => [104];
        assert_script_run '! rpm -q etcd';
    }
    # Should have unconfigured Kubernetes & container runtime environment
    if (check_var('SYSTEM_ROLE', 'kubeadm')) {
        assert_script_run 'which crio';
        zypper_call 'se -i kubernetes';
    }
}

sub run {
    run_rcshell_checks;
    return if get_var('EXTRA', '') =~ /RCSHELL/;

    run_common_checks;
    run_microos_checks;
}

1;
