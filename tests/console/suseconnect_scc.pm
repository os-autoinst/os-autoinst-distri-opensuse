# SUSE openQA tests
#
# Copyright 2017-2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Package: SUSEConnect
# Summary: Register system image against SCC
# Maintainer: qac <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use testapi;
use utils qw(zypper_call script_retry);
use version_utils qw(is_sle is_jeos is_sle_micro);
use registration qw(register_addons_cmd verify_scc investigate_log_empty_license);

sub run {
    return if get_var('HDD_SCC_REGISTERED');
    my $self = shift;
    my $reg_code = get_required_var 'SCC_REGCODE';
    my $cmd = "SUSEConnect -r $reg_code";
    my $scc_addons = get_var 'SCC_ADDONS', '';
    # fake scc url pointing to synced repos on openQA
    # valid only for products currently in development
    # please unset in job def *SCC_URL* if not required
    my $fake_scc = get_var 'SCC_URL', '';
    $cmd .= ' --url ' . $fake_scc if $fake_scc;


    $self->select_serial_terminal;
    die 'SUSEConnect package is not pre-installed!' if script_run 'command -v SUSEConnect';
    if ((is_jeos || is_sle_micro) && script_run(q(SUSEConnect --status-text | grep -i 'not registered'))) {
        die 'System has been already registered!';
    }

    # There are sporadic failures due to the command timing out, so we increase the timeout
    # and make use of retries to overcome a possible sporadic network issue.
    script_retry("$cmd", retry => 5, delay => 60, timeout => 180);
    # Check available extenstions (only present in sle)
    assert_script_run q[SUSEConnect --list-extensions];
    if (is_sle) {
        # What has been activated by default
        assert_script_run q[SUSEConnect --list-extensions | grep -e '\(Activated\)'];
        assert_script_run 'SUSEConnect --list-extensions | grep "$(echo -en \'    \e\[1mServer Applications Module\')"' unless is_sle('=12-sp5');
        assert_script_run 'SUSEConnect --list-extensions | grep "$(echo -en \'    \e\[1mWeb and Scripting Module\')"';
    }

    # add modules
    register_addons_cmd if $scc_addons;
    # Check that repos actually work
    zypper_call 'refresh';
    zypper_call 'repos --details';
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;
    verify_scc;
    investigate_log_empty_license unless (script_run 'test -f /var/log/YaST2/y2log');
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
