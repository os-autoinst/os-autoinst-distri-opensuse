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
use strict;

my %profiles = (
    hana   => 'sap-hana',
    b1     => 'sap-hana',
    ase    => 'sap-ase',
    sybase => 'sap-ase',
    bobj   => 'sap-bobj'
);

sub check_profile {
    my $current = shift;
    my $output  = script_output "tuned-adm active";
    die "Tuned profile change failed. Expected 'Current active profile: $profiles{$current}', got: [$output]"
      unless ($output =~ /Current active profile: $profiles{$current}/);
}

sub run {
    my ($self) = @_;

    select_console 'root-console';

    my $output = script_output "sapconf status";
    my $statusregex
      = 'tuned.service - Dynamic System Tuning Daemon.+'
      . 'Loaded: loaded \(/usr/lib/systemd/system/tuned.service;.+'
      . 'Active: active \(running\).+'
      . 'Starting Dynamic System Tuning Daemon.+'
      . 'Started Dynamic System Tuning Daemon.$';
    die "Command 'sapconf status' output is not recognized" unless ($output =~ m|$statusregex|s);

    $output = script_output "tuned-adm active";
    $output =~ /Current active profile: ([a-z\-]+)/;
    my $default_profile = $1;
    record_info("Current profile", "Current default profile: $default_profile");

    foreach my $cmd ('start', keys %profiles) {
        $output = script_output "sapconf $cmd";
        die "Command 'sapconf $cmd' output is not recognized" unless ($output =~ /Forwarding action to tuned\-adm\./);
        next if ($cmd eq 'start');
        check_profile($cmd);
    }

    # Set default profile again
    assert_script_run "tuned-adm profile $default_profile";
}

1;
# vim: set sw=4 et:
