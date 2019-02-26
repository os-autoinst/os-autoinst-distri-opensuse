# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: sapconf availability and basic commands to tuned-adm
# Maintainer: Alvaro Carvajal <acarvajal@suse.de>

use base "sles4sap";
use testapi;
use version_utils qw(is_staging is_sle);
use strict;
use warnings;

my @tuned_profiles = is_sle('>=15') ?
  qw(balanced desktop latency-performance network-latency network-throughput
  powersave sapconf saptune throughput-performance virtual-guest virtual-host)
  : qw(balanced desktop latency-performance network-latency
  network-throughput powersave sap-ase sap-bobj sap-hana sap-netweaver
  throughput-performance virtual-guest virtual-host);

my %sapconf_profiles = (
    hana   => 'sap-hana',
    b1     => 'sap-hana',
    ase    => 'sap-ase',
    sybase => 'sap-ase',
    bobj   => 'sap-bobj'
);

sub check_profile {
    my $current = shift;
    my $output  = script_output "tuned-adm active";
    my $profile = is_sle('>=15') ? $current : $sapconf_profiles{$current};
    die "Tuned profile change failed. Expected 'Current active profile: $profile', got: [$output]"
      unless ($output =~ /Current active profile: $profile/);
}

sub save_tuned_conf {
    my $tag = shift;
    my $log = "/tmp/conf_and_logs_$tag.tar.gz";
    script_run "tar -zcf $log /etc/tuned/* /var/log/tuned/*";
    upload_logs $log;
}

sub run_developers_tests {
    my $devel_repo = 'https://gitlab.suse.de/AngelaBriel/sapconf-test/repository/master/archive.tar.gz';
    my $log        = '/tmp/sapconf_test.log';

    save_tuned_conf 'before';

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

    save_tuned_conf 'after';
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

    select_console 'root-console';

    assert_script_run("rpm -q sapconf");

    my $output = script_output "tuned-adm active";
    $output =~ /Current active profile: ([a-z\-]+)/;
    my $default_profile = $1;
    record_info("Current profile", "Current default profile: $default_profile");

    verify_sapconf_service('tuned.service',   'Dynamic System Tuning Daemon');
    verify_sapconf_service('sapconf.service', 'sapconf') unless ($default_profile eq 'saptune');
    verify_sapconf_service('uuidd.socket',    'UUID daemon activation socket');
    verify_sapconf_service('sysstat.service', 'Write information about system start to sysstat log')
      if (is_sle('>=15'));

    my $statusregex = join('.+', @tuned_profiles);
    $output = script_output "tuned-adm list";
    die "Command 'tuned-adm list' output is not recognized" unless ($output =~ m|$statusregex|s);

    $output = script_output "tuned-adm recommend";
    record_info("Recommended profile", "Recommended profile: $output");
    die "Command 'tuned-adm recommend' recommended profile is not in 'tuned-adm list'"
      unless (grep(/$output/, @tuned_profiles));

    foreach my $p (@tuned_profiles) {
        assert_script_run "tuned-adm profile_info $p" if is_sle('>=15');
        assert_script_run "tuned-adm profile $p";
        check_profile($p);
    }

    unless (is_sle('>=15')) {
        foreach my $cmd ('start', keys %sapconf_profiles) {
            $output = script_output "sapconf $cmd";
            die "Command 'sapconf $cmd' output is not recognized"
              unless ($output =~ /Forwarding action to tuned\-adm\./);
            next if ($cmd eq 'start');
            check_profile($cmd);
        }
    }

    assert_script_run "tuned-adm off";
    $output = script_output "tuned-adm active || true";
    die "Command 'tuned-adm off' failed to disable profile" unless ($output =~ /No current active profile/);

    # Set default profile again
    assert_script_run "tuned-adm profile $default_profile";

    run_developers_tests unless (is_staging() or ($default_profile eq 'saptune'));
}

1;
