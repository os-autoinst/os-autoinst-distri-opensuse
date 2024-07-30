# SUSE openQA tests
#
# Copyright 2017-2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Package: SUSEConnect
# Summary: Register system image against SCC
# Maintainer: qac <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(zypper_call script_retry script_output_retry);
use version_utils qw(is_sle is_jeos is_sle_micro is_transactional is_staging);
use registration qw(register_addons_cmd verify_scc investigate_log_empty_license);
use transactional qw(trup_call process_reboot);

sub run {
    return if get_var('HDD_SCC_REGISTERED');
    my $cmd = ' -r ' . get_required_var 'SCC_REGCODE';
    my $scc_addons = get_var 'SCC_ADDONS', '';
    # fake scc url pointing to synced repos on openQA
    # valid only for products currently in development
    # please unset in job def *SCC_URL* if not required
    my $fake_scc = get_var 'SCC_URL', '';
    $cmd .= ' --url ' . $fake_scc if $fake_scc;
    my $retries = 5;    # number of retries to run SUSEConnect commands
    my $delay = 60;    # time between retries to run SUSEConnect commands


    select_serial_terminal;
    die 'SUSEConnect package is not pre-installed!' if script_run 'command -v SUSEConnect';
    if ((is_jeos || is_sle_micro) && script_run(qq(SUSEConnect --status-text | grep -i 'not registered'))) {
        die 'System has been already registered!';
    }

    # There are sporadic failures due to the command timing out, so we increase the timeout
    # and make use of retries to overcome a possible sporadic network issue.
    # script_output_retry is useless for `transactional-update` cmd because it returns 0 even with failure
    # trup_call will raise a failure if the command fails
    if (is_transactional) {
        trup_call('register' . $cmd);
        trup_call('--continue run zypper --gpg-auto-import-keys refresh') if is_staging;
        process_reboot(trigger => 1);
    }
    else {
        my $output = script_output_retry("SUSEConnect $cmd", retry => $retries, delay => $delay, timeout => 180);
        die($output) if ($output =~ m/error|timeout|problem retrieving/i);
    }
    # Check available extenstions (only present in sle)
    my $extensions = script_output_retry("SUSEConnect --list-extensions", retry => $retries, delay => $delay, timeout => 180);
    record_info('Extensions', $extensions);

    die("None of the modules are Activated") if ($extensions !~ m/Activated/ && is_sle);

    # add modules
    register_addons_cmd($scc_addons, $retries) if $scc_addons;
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
