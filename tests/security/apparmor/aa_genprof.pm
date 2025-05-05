# Copyright 2018-2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: screen apparmor-utils audit smbd
# Summary: Test the profile generation utility of Apparmor using aa-genprof.
# - Starts auditd
# - Creates a temporary profile dir in /tmp
# - Run "aa-genprof -d /tmp/apparmor.d smbd" inside a screen
# - While the command is running, detach screen and restart smbd
# - Reattach screen and continue execution (interactive mode)
# - Run "cat /tmp/apparmor.d/usr.sbin.smbd" and check the output for a set of
# parameters
# - Run function "aa_tmp_prof_verify" (check if program is able to start using
# the temporary profiles)
# - Clean the temporary profiles directory
# Maintainer: QE Security <none@suse.de>
# Tags: poo#36886, poo#45803

use strict;
use warnings;
use base "apparmortest";
use testapi;
use utils;
use version_utils qw(is_sle);
use serial_terminal qw(select_serial_terminal);

sub run {
    my ($self) = @_;

    my $aa_tmp_prof = "/tmp/apparmor.d";
    my $sc_dtch_msg = "Screen detached";
    my $sc_term_msg = "Screen terminated";
    my $test_pkg = is_sle('<=15-sp4') ? 'nscd' : 'samba';
    my $test_bin = is_sle('<=15-sp4') ? 'nscd' : 'smbd';
    my $test_service = is_sle('<=15-sp4') ? 'nscd' : 'smb';

    zypper_call("in $test_pkg");

    systemctl('start auditd');

    $self->aa_tmp_prof_prepare("$aa_tmp_prof");

    assert_script_run("rm -f  $aa_tmp_prof/usr.sbin.$test_bin");

    # Run aa-genprof command in screen so that we could restart smbd at the
    # same time while it is waiting for scan
    select_console 'root-console';
    script_run("screen -m ; echo '$sc_dtch_msg' > /dev/$serialdev", 0);

    # Confirm it is in the screen
    validate_script_output "echo \$TERM", sub { m/screen/ };

    script_run_interactive("aa-genprof -d $aa_tmp_prof $test_bin", undef);
    wait_serial("Please start the application", 20);

    # Detach screen
    send_key 'ctrl-a';
    sleep 1;
    send_key 'd';
    wait_serial("$sc_dtch_msg", 10);    # confirm detached

    systemctl("restart $test_service");
    sleep 3;

    # reattach screen
    script_run("screen -r ; echo '$sc_term_msg' > /dev/$serialdev", 0);
    send_key 's';

    script_run_interactive(
        undef,
        [
            {
                prompt => qr/\(A\)llow.*\(D\)eny/m,
                key => 'a',
            },
            {
                prompt => qr/\(S\)ave Changes/m,
                key => 's',
            },
            {
                prompt => qr/\(S\)can system.*\(F\)inish/m,
                key => 'f',
            },
        ],
        30
    );

    # Exit screen
    send_key 'ctrl-d';
    wait_serial("$sc_term_msg", 10);    # confirm terminated
    select_serial_terminal;

    # Not all rules will be checked here, only the critical ones.
    validate_script_output "cat $aa_tmp_prof/usr.sbin.$test_bin", sub {
        m/
		    include\s+<tunables\/global>.*
            \/usr\/sbin\/$test_bin\s*{.*
            include\s+<abstractions\/base>.*
            \/usr\/sbin\/$test_bin\s+mr.*
            }/sxx
    };

    $self->aa_tmp_prof_verify("$aa_tmp_prof", "$test_service");
    $self->aa_tmp_prof_clean("$aa_tmp_prof");
}

1;
