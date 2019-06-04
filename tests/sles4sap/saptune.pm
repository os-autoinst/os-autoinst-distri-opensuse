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
use version_utils 'is_sle';
use Utils::Architectures 'is_ppc64le';
use strict;
use warnings;

sub tuned_is {
    my $pattern = shift;
    my $output  = script_output "saptune daemon status 2>&1 || true";
    $output =~ /Daemon \(tuned\.service\) is $pattern./;
}

sub run {
    my ($self) = @_;

    # Test has to work differently on x86_64 and ppc64le. Will verify test
    # is running on ppc64le via the OFW variable
    my $is_ppc64le = get_var('OFW');

    # List of solutions is different between saptune in x86_64 and in ppc64le
    my @solutions
      = $is_ppc64le ?
      qw(HANA MAXDB NETWEAVER S4HANA-APPSERVER S4HANA-DBSERVER)
      : qw(BOBJ HANA MAXDB NETWEAVER S4HANA-APPSERVER S4HANA-DBSERVER SAP-ASE);

    # Skip test if SLES4SAP version is before 15 and running on ppc64le
    return if (is_sle('<15') and $is_ppc64le);

    select_console 'root-console';

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

    my $output = script_output "saptune solution list";
    my $regexp = join('.+', @solutions);
    die "Command 'saptune solution list' output is not recognized" unless ($output =~ m|$regexp|s);

    $output = script_output "saptune note list";
    $regexp = 'All notes \(\+ denotes manually enabled notes, \* denotes notes enabled by solutions\):';
    die "Command 'saptune note list' output is not recognized" unless ($output =~ m|$regexp|);
}

1;
