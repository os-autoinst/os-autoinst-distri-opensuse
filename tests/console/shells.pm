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

use Mojo::Base 'consoletest';
use testapi qw(is_serial_terminal :DEFAULT);
use Utils::Architectures;
use package_utils 'install_package';
use serial_terminal qw(select_user_serial_terminal select_serial_terminal);
use version_utils qw(is_leap is_sle);

sub run() {
    select_serial_terminal();
    my @packages = qw(tcsh zsh);
    # ksh does not build for Leap 15.x on aarch64, so, skip it
    push @packages, qw(ksh) unless (is_leap('15.0+') and is_aarch64);
    install_package("@packages", trup_reboot => 1);
    select_user_serial_terminal();
    assert_script_run 'ksh -c "print hello" | grep hello' unless (is_leap('15.0+') and is_aarch64);
    assert_script_run 'tcsh -c "printf \'hello\n\'" | grep hello';
    assert_script_run 'csh -c "printf \'hello\n\'" | grep hello';
    assert_script_run 'zsh -c "echo hello" | grep hello' unless (is_sle("16+"));
    assert_script_run 'sh -c "echo hello" | grep hello';
    tcsh_extra_tests();
}

sub wait_for_prompt {
    my ($prompt) = @_;
    if (is_serial_terminal()) {
        wait_serial($prompt, timeout => 60);
    }
    else {
        wait_still_screen(3);
    }
}

#tcsh specializated test for bsc#1154877 && poo#59354:
sub tcsh_extra_tests {
    select_serial_terminal();
    script_run 'useradd -s /usr/bin/tcsh -d /home/tcsh_user -m tcsh_user';
    enter_cmd 'su - tcsh_user';
    wait_for_prompt(qr/> $/);

    #Generate some outputs for the new created user:
    enter_cmd "echo \"echo Sourced!\" >> ~/.tcsh";

    enter_cmd "grep tcsh_user /etc/passwd > /tmp/tcsh";
    enter_cmd "echo \$SHELL >> /tmp/tcsh";
    enter_cmd "echo ~ >> /tmp/tcsh";
    enter_cmd "source ~/.tcsh >> /tmp/tcsh";
    enter_cmd "ls -d /* |grep -wc '/bin\\|/home\\|/root\\|/lib\\|/usr\\|/var\\|/proc\\|/sys\\|/boot\\|/sbin\\|/tmp\\|/opt' >> /tmp/tcsh";

    #Go back to root/openqa and do the validations:
    enter_cmd 'logout';
    # On serial the first validation's script_run waits for the root
    # prompt; consuming it here would make that wait time out.
    wait_still_screen(3) unless is_serial_terminal();

    validate_script_output 'grep -c /home/tcsh_user:/usr/bin/tcsh /tmp/tcsh', sub { /1/ }, timeout => 60;
    validate_script_output 'grep -c ^/usr/bin/tcsh /tmp/tcsh', sub { /1/ }, timeout => 60;
    validate_script_output 'grep -c ^/home/tcsh_user /tmp/tcsh', sub { /1/ }, timeout => 60;
    validate_script_output 'grep -c Sourced! /tmp/tcsh', sub { /1/ }, timeout => 60;
    validate_script_output 'grep 12 /tmp/tcsh', sub { /12/ }, timeout => 60;

    #cleanup:
    script_run 'rm /tmp/tcsh ~/.tcsh';
    script_run 'userdel tcsh_user';
}

sub post_fail_hook {
    my ($self) = @_;
    select_serial_terminal();
    enter_cmd 'test -n "$tcsh" && exit';
    wait_still_screen(3) unless is_serial_terminal();
    script_run 'rm -f /tmp/tcsh';
    script_run 'id -u tcsh_user >/dev/null && userdel -r tcsh_user';
    $self->SUPER::post_fail_hook;
}

sub test_flags {
    return {fatal => 0, no_rollback => 1};
}

1;
