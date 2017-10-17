# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: saptune availability and basic commands to the tuned daemon
# Maintainer: Alvaro Carvajal <acarvajal@suse.de>

use base "opensusebasetest";
use testapi;
use utils;
use strict;

sub is_tuned {
    my ($pattern, $text) = @_;
    $text =~ /^Daemon \(tuned\.service\) is $pattern./;
}

sub run {
    my ($self)       = @_;
    my $prev_console = $testapi::selected_console;
    my @solutions    = qw(BOBJ HANA MAXDB NETWEAVER S4HANA-APPSERVER S4HANA-DBSERVER SAP-ASE);

    select_console 'root-console';

    my $output = script_output "saptune daemon status || true";
    die "Command 'saptune daemon status' returned unexpected output. Expected tuned to be running"
      unless (is_tuned 'running', $output);

    assert_script_run "saptune daemon stop";
    $output = script_output "saptune daemon status 2>&1 || true";
    die "Command 'saptune daemon stop' couldn't stop tuned"
      unless (is_tuned 'stopped', $output);

    assert_script_run "saptune daemon start";
    $output = script_output "saptune daemon status || true";
    die "Command 'saptune daemon start' couldn't start tuned"
      unless (is_tuned 'running', $output);

    $output = script_output "saptune solution list";
    my $regexp = join('.+', @solutions);
    die "Command 'saptune solution list' output is not recognized" unless ($output =~ m|$regexp|s);

    $output = script_output "saptune note list";
    die "Command 'saptune note list' output is not recognized"
      unless ($output =~ m|^All notes \(\+ denotes manually enabled notes, \* denotes notes enabled by solutions\):|);

    # Return to previous console
    select_console($prev_console, await_console => 0);
    ensure_unlocked_desktop if ($prev_console eq 'x11');
}

1;
# vim: set sw=4 et:
