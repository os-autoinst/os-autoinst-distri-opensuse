# SUSE's openQA tests
#
# Copyright 2017-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: tcsh zsh bash shadow util-linux
# Summary: Test all officially SLE supported shells
# - Install tcsh and zsh (when supported)
# - Run ksh -c "print hello" | grep hello (when supported)
# - Run 'csh -c "printf \'hello\n\'" | grep hello'
# - Run 'zsh -c "echo hello" | grep hello'
# - Run 'sh -c "echo hello" | grep hello'
#
# - tcsh:
# - Run 'tcsh -c "printf \'hello\n\'" | grep hello'
# - Check if ~ is expanding correctly
# - Check if ~/.tcsh is correctly sourced
# - Check if directories are listed correctly with ls -d /*
# Maintainer: QE Core <qe-core@suse.de>

use base "consoletest";
use testapi;
use Utils::Architectures;
use utils 'zypper_call';
use serial_terminal qw(select_user_serial_terminal select_serial_terminal);
use version_utils qw(is_leap is_sle);

sub run() {
    select_serial_terminal();
    my @packages = qw(tcsh zsh);
    # ksh does not build for Leap 15.x on aarch64, so, skip it
    push @packages, qw(ksh) unless (is_leap('15.0+') and is_aarch64);
    zypper_call("in @packages");
    select_user_serial_terminal();
    assert_script_run 'ksh -c "print hello" | grep hello' unless (is_leap('15.0+') and is_aarch64);
    assert_script_run 'tcsh -c "printf \'hello\n\'" | grep hello';
    assert_script_run 'csh -c "printf \'hello\n\'" | grep hello';
    assert_script_run 'zsh -c "echo hello" | grep hello' unless (is_sle("16+"));
    assert_script_run 'sh -c "echo hello" | grep hello';
    tcsh_extra_tests();
}

#tcsh specializated test for bsc#1154877 && poo#59354:
sub tcsh_extra_tests {
    select_console 'root-console';
    script_run 'useradd -s /usr/bin/tcsh -d /home/tcsh_user -m tcsh_user';
    script_run 'su - tcsh_user', 0;
    wait_still_screen(3);

    #Generate some outputs for the new created user:
    enter_cmd "echo \"echo Sourced!\" >> ~/.tcsh";

    enter_cmd "grep tcsh_user /etc/passwd > /tmp/tcsh";
    enter_cmd "echo \$SHELL >> /tmp/tcsh";
    enter_cmd "echo ~ >> /tmp/tcsh";
    enter_cmd "source ~/.tcsh >> /tmp/tcsh";
    enter_cmd "ls -d /* |grep -wc '/bin\\|/home\\|/root\\|/lib\\|/usr\\|/var\\|/proc\\|/sys\\|/boot\\|/sbin\\|/tmp\\|/opt' >> /tmp/tcsh";

    #Go back to root/openqa and do the validations:
    script_run 'logout', 0;
    wait_still_screen(3);

    validate_script_output 'grep -c /home/tcsh_user:/usr/bin/tcsh /tmp/tcsh', sub { /1/ }, timeout => 60;
    validate_script_output 'grep -c ^/usr/bin/tcsh /tmp/tcsh', sub { /1/ }, timeout => 60;
    validate_script_output 'grep -c ^/home/tcsh_user /tmp/tcsh', sub { /1/ }, timeout => 60;
    validate_script_output 'grep -c Sourced! /tmp/tcsh', sub { /1/ }, timeout => 60;
    validate_script_output 'grep 12 /tmp/tcsh', sub { /12/ }, timeout => 60;

    #cleanup:
    script_run 'rm /tmp/tcsh ~/.tcsh';
    script_run 'userdel tcsh_user';
}

1;
