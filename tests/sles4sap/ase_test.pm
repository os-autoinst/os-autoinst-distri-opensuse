# SUSE's SLES4SAP openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: SAP ASE smoke test. Run some commands and queries to verify SAP ASE is running
# Requires: sles4sap/ase_install
# Maintainer: QE-SAP <qe-sap@suse.de>

use base "sles4sap";
use strict;
use warnings;
use Carp qw(croak);
use testapi;
use serial_terminal qw(select_serial_terminal);

sub run_ase_query {
    my %args = @_;
    croak "Got no query!" unless $args{query};
    $args{timeout} //= 30;
    assert_script_run "echo '$args{query}' > query.file; echo go >> query.file";
    assert_script_run 'cat query.file';
    script_output "isql -Usa -P$testapi::password -SSYBASE -i query.file", $args{timeout};
}

sub is_ase_up {
    my ($t) = @_;

    # showserver will produce an output like this:
    #
    # F S UID        PID  PPID  C PRI  NI ADDR SZ WCHAN  STIME TTY          TIME CMD
# 4 S root     25985 25984 10  80   0 - 286666 futex_ 17:47 ?       00:00:57 /opt/sap/ASE-16_0/bin/dataserver -sSYBASE -d/opt/sap/data/master.dat -e/opt/sap/ASE-16_0/install/SYBASE.log -c/opt/sap/ASE-16_0/SYBASE.cfg -M/opt/sap/ASE-16_0 -N/opt/sap/ASE-16_0/sysam/SYBASE.properties -i/opt/sap
# 0 S root     26194 26193  0  80   0 -  5072 do_sys 17:48 ?        00:00:00 /opt/sap/ASE-16_0/bin/backupserver -e/opt/sap/ASE-16_0/install/SYBASE_BS.log -N25 -C20 -I/opt/sap/interfaces -M/opt/sap/ASE-16_0/bin/sybmultbuf -SSYBASE_BS
    #
    # To confirm ASE is up, we need to look at the line with dataserv. The 4 conditions below
    # were identified as belonging to the database server and not to the other servers, so we are
    # using all 4 conditions to determine ASE is up
    return ($t =~ /dataserver / && $t =~ /SYBASE\.properties/ && $t =~ /SYBASE\.cfg/ && $t =~ /\-sSYBASE[^_]/);
}

sub run {
    my ($self) = @_;
    my $response_file = get_required_var('ASSET_1');
    $response_file =~ s/.gz$//;
    $self->ASE_RESPONSE_FILE($response_file);    # This module verifies SAP-ASE. We need to supply it with the response file name

    # Define some variables with the scripts and files to be used while testing
    my $showserver = '$SYBASE/$SYBASE_ASE/install/showserver';
    my $cockpit_script = '$SYBASE/COCKPIT-4/bin/cockpit.sh';
    my $second_log = '$HOME/second_ase_start.log';

    select_serial_terminal;
    enter_cmd 'cd';    # Let's start in $HOME
    $self->load_ase_env;

    # Is ASE running?
    my $out = script_output $showserver;
    die 'SAP ASE is not running' unless is_ase_up($out);
    record_info 'showserver', $out;

    # Can we connect to ASE?
    $out = run_ase_query(query => 'select @@version');
    die "Failed to run query. Error: [$out]" unless ($out =~ /row affected/);
    record_info 'ASE Version', $out;

    # Can ASE be stopped and started?
    $out = run_ase_query(query => 'shutdown', timeout => 300);
    die 'Problems detected while attempting a shutdown of ASE' unless ($out =~ /Server SHUTDOWN by request/ && $out =~ /ASE is terminating this process/);
    $out = script_output $showserver;
    die 'SAP ASE is still running' if is_ase_up($out);
    # Start SAP ASE and send the output to a log file to upload to the test results
    enter_cmd '$SYBASE/$SYBASE_ASE/install/RUN_SYBASE > ' . $second_log . ' 2>&1 &';    # Sadly, ASE start script is not daemonized, so run it with &
                                                                                        # Wait until ASE finishes starting
    send_key 'ret';    # Type enter to get a shell prompt
    assert_script_run "until (grep -q 'This software contains confidential and trade secret information of SAP AG' $second_log); do sleep 5; done", timeout => 300;
    $out = script_output $showserver;
    die 'SAP ASE is not running' unless is_ase_up($out);
    upload_logs $second_log;

    # Check ASE cockpit
    $out = script_output "$cockpit_script -status";
    die 'Cockpit server is not running' unless ($out =~ /Cockpit server is running/);
    record_info 'Cockpit Server', script_output "$cockpit_script --info";
    assert_script_run "$cockpit_script -stop";
    $out = script_output "$cockpit_script -status";
    die 'Cockpit server is not stopped' unless ($out =~ /Cockpit server is stopped/);
    # Now to start the cockpit server, it's not possible to do so and detach from the script
    # without killing the cockpit server, so we start this in a different terminal to avoid
    # blocking the serial terminal
    select_console 'root-console';
    $self->load_ase_env;
    enter_cmd "$cockpit_script -start";
    assert_screen 'sap-ase-cockpit', 300;
    select_serial_terminal;
    $out = script_output "$cockpit_script -status";
    die 'Cockpit server is not running' unless ($out =~ /Cockpit server is running.+:4992$/);
}

1;
