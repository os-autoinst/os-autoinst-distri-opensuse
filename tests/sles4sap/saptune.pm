# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: saptune availability and basic commands to the tuned daemon
# Maintainer: Alvaro Carvajal <acarvajal@suse.de>

use base "sles4sap";
use testapi;
use utils "zypper_call";
use version_utils qw(is_sle is_upgrade);
use strict;
use warnings;

sub tuned_is {
    my $pattern = shift;
    my $output  = script_output "saptune daemon status 2>&1 || true";
    $output =~ /Daemon \(tuned\.service\) is $pattern./;
}

sub run {
    my ($self) = @_;

    my @solutions = qw(BOBJ HANA MAXDB NETWEAVER NETWEAVER\+HANA S4HANA-APP\+DB S4HANA-APPSERVER S4HANA-DBSERVER SAP-ASE);

    select_console 'root-console';

    # saptune is not installed by default on SLES4SAP 12 on ppc64le
    zypper_call "-n in saptune" if (get_var('OFW') and is_sle('<15'));

    unless (tuned_is 'running') {
        assert_script_run "saptune daemon start";
    }

    die "Command 'saptune daemon status' returned unexpected output. Expected tuned to be running"
      unless (tuned_is 'running');

    assert_script_run "saptune daemon stop";
    die "Command 'saptune daemon stop' didn't stop tuned"
      unless (tuned_is 'stopped');

    assert_script_run "saptune daemon start";
    die "Command 'saptune daemon start' didn't start tuned"
      unless (tuned_is 'running');

    # Skip test if saptune version is 1
    return if (is_upgrade() and script_output("saptune version") =~ m/current active saptune version is '1'/);

    my $output = script_output "saptune solution list";
    my $regexp = join('.+', @solutions);
    die "Command 'saptune solution list' output is not recognized" unless ($output =~ m|$regexp|s);

    $output = script_output "saptune note list";
    $regexp = 'All notes \(\+ denotes manually enabled notes, \* denotes notes enabled by solutions';
    die "Command 'saptune note list' output is not recognized" unless ($output =~ m|$regexp|);
}

1;
