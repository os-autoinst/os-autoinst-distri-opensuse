# SUSE's openQA tests
#
# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: dialog
# Summary: Ensure simple ncurses applications can start and look correct
# - Install dialog
# - Run "dialog --yesno "test for boo#1054448"
# - If screen matches, add export TERM=linux to /etc/profile
# - Run export TERM=linux  and start root console
# Maintainer: QE Core <qe-core@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(clear_console zypper_call);

sub run {
    select_serial_terminal;
    zypper_call 'in dialog';
    select_console 'root-console';

    # Try to draw a bold red line
    script_run('echo "$(tput smacs;tput setaf 1;tput bold)lqqqqqqqqqqqqqqk$(tput rmacs;tput sgr0)"');
    # Try a simple yes/no dialog
    enter_cmd 'dialog --yesno "test for boo#1054448" 3 20 | tee boo_1054448.tee';
    assert_screen([qw(ncurses-simple-dialog ncurses-simple-dialog-broken-boo1183234)]);
    if (match_has_tag 'ncurses-simple-dialog-broken-boo1183234') {
        die "boo#1183234: Console misconfigured, ncurses UI broken!\n";
    }
    send_key 'ret';
    clear_console;
    if (match_has_tag 'boo#1054448') {
        record_soft_failure 'boo#1054448';
        my $cmd = 'export TERM=linux';
        assert_script_run "$cmd && echo '$cmd' > /etc/profile";
        select_console 'user-console';
        assert_script_run "$cmd";
        select_console 'root-console';
    }
}

sub post_fail_hook {
    my $self = shift;
    $self->SUPER::post_fail_hook;
    upload_logs('/etc/sysconfig/console');
    upload_logs('boo_1054448.tee');
    script_run('echo $TERM');
}

1;
