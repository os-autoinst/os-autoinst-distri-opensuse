# SUSE's openQA tests
#
# Copyright © 2017-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: sapconf availability and basic commands to tuned-adm
# Working both on plain SLE and SLES4SAP products
# Maintainer: Alvaro Carvajal <acarvajal@suse.de>

use base "sles4sap";
use testapi;
use version_utils qw(is_staging is_sle is_upgrade);
use Utils::Architectures 'is_x86_64';
use Utils::Systemd 'systemctl';
use strict;
use warnings;

sub run_developers_tests {
    my $devel_repo = 'https://gitlab.suse.de/AngelaBriel/sapconf-test/repository/master/archive.tar.gz';
    my $log        = '/tmp/sapconf_test.log';

    # Download and unpack the test scripts supplied by the developers
    # Continue if it can not be downloaded
    type_string "cd /tmp\n";
    my $ret = script_run "curl -k $devel_repo | tar -zxvf -";
    unless (defined $ret and $ret == 0) {
        record_info 'Download problem', 'Could not download developer test script';
        return;
    }

    # Run script as is and upload results
    $ret = script_run 'cd sapconf-test-master-*';
    unless (defined $ret and $ret == 0) {
        record_info 'Script not found', 'sapconf-test-master-* directory not found in the developer test package';
        return;
    }
    my $output = script_output 'ls';
    if ($output !~ /sapconf_test\.sh/) {
        record_info 'Script not found', 'Script sapconf_test.sh is not in the developer test package';
        return;
    }
    assert_script_run "chmod +x sapconf_test.sh";
    $ret = script_run "./sapconf_test.sh -c local -p no | tee $log", 600;
    # Record soft fail only if script returns an error. Ignore timeout as test completion is checked below
    record_info('Test failed', "sapconf_test.sh returned error code: [$ret]", result => 'softfail') if (defined $ret and $ret != 0);
    upload_logs $log;

    # Check summary of tests on log for bug report
    my $report = script_output "grep ^Test $log || true";
    record_info('Summaries', 'No tests summaries in log', result => 'softfail') unless ($report);
    foreach my $summary (split(/[\r\n]+/, $report)) {
        next unless ($summary =~ /^Test/);
        # Do nothing with passing tests. The summary will be shown on the script_output step
        next if ($summary =~ /PASSED$/);
        # Skip results of fate#325548 on SLES4SAP versions before 15
        next if ($summary =~ /fate325548/ and is_sle('<15'));
        if ($summary =~ /Test #(bsc|fate)([0-9]+)/) {
            record_soft_failure "$1#$2";
        }
        else {
            record_info $summary, "Test summary: $summary", result => 'fail';
        }
    }

    # Return to homedir just in case
    type_string "cd\n";
}

sub verify_sapconf_service {
    my ($svc, $desc) = @_;

    my $output      = script_output "systemctl status $svc";
    my $statusregex = $svc . ' - ' . $desc . '.+' . 'Loaded: loaded \(/usr/lib/systemd/system/' . $svc . ';.+';
    my $active      = $statusregex . 'Active: active \((listening|running)\).+';
    my $success     = $statusregex . 'Active: active \(exited\).+' . 'status=0\/SUCCESS';
    die "Command 'systemctl status $svc' output is not recognized" unless ($output =~ m|$active|s or $output =~ m|$success|s);
}

sub run {
    my ($self) = @_;

    $self->select_serial_terminal;

    assert_script_run("rpm -q sapconf");

    if (is_upgrade()) {
        # Stop & disable tuned service to avoid conflict with active saptune
        systemctl "stop tuned";
        systemctl "disable tuned";
        # Some versions of sapconf check for this directory and refuse to start
        assert_script_run "rm -rf /var/lib/saptune/saved_state";
        systemctl "enable sapconf";
        systemctl "start sapconf";
    }

    my $default_profile = $1;
    record_info("Current profile", "Current default profile: $default_profile");

    verify_sapconf_service('sapconf.service', 'sapconf') unless ($default_profile eq 'saptune');
    verify_sapconf_service('uuidd.socket',    'UUID daemon activation socket');
    verify_sapconf_service('sysstat.service', 'Write information about system start to sysstat log')
      if is_sle('15+');

    my $sapconf_bin = is_sle('<15') ? 'sapconf' : '/usr/lib/sapconf/sapconf';
    if (is_sle('<15')) {
        my @sapconf_profiles = ('netweaver', 'hana', 'b1', 'ase', 'sybase', 'bobj');
        foreach my $cmd (@sapconf_profiles) {
            assert_script_run "$sapconf_bin stop && $sapconf_bin $cmd && $sapconf_bin start && $sapconf_bin status";
        }
    } else {
        assert_script_run "$sapconf_bin stop && $sapconf_bin start && $sapconf_bin status";
    }

    run_developers_tests unless (is_staging());
}

1;
