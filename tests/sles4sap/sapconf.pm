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
use version_utils 'sle_version_at_least';
use strict;

my @tuned_profiles = qw(balanced desktop latency-performance network-latency
  network-throughput powersave sap-ase sap-bobj sap-hana sap-netweaver saptune
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
    my $profile = sle_version_at_least('15') ? $current : $sapconf_profiles{$current};
    die "Tuned profile change failed. Expected 'Current active profile: $profile', got: [$output]"
      unless ($output =~ /Current active profile: $profile/);
}

sub run {
    my ($self) = @_;

    select_console 'root-console';

    my $output = script_output "systemctl status tuned";
    my $statusregex
      = 'tuned.service - Dynamic System Tuning Daemon.+'
      . 'Loaded: loaded \(/usr/lib/systemd/system/tuned.service;.+'
      . 'Active: active \(running\).+'
      . 'Starting Dynamic System Tuning Daemon.+'
      . 'Started Dynamic System Tuning Daemon.';
    die "Command 'systemctl status tuned' output is not recognized" unless ($output =~ m|$statusregex|s);

    assert_script_run("rpm -q sapconf");

    $output = script_output "tuned-adm active";
    $output =~ /Current active profile: ([a-z\-]+)/;
    my $default_profile = $1;
    record_info("Current profile", "Current default profile: $default_profile");

    $statusregex = join('.+', @tuned_profiles);
    $output = script_output "tuned-adm list";
    die "Command 'tuned-adm list' output is not recognized" unless ($output =~ m|$statusregex|s);

    $output = script_output "tuned-adm recommend";
    record_info("Recommended profile", "Recommended profile: $output");
    die "Command 'tuned-adm recommended' recommended profile is not in 'tuned-adm list'"
      unless (grep(/$output/, @tuned_profiles));

    foreach my $p (@tuned_profiles) {
        assert_script_run "tuned-adm profile_info $p" if sle_version_at_least('15');
        assert_script_run "tuned-adm profile $p";
        check_profile($p);
    }

    unless (sle_version_at_least('15')) {
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
}

1;
# vim: set sw=4 et:
