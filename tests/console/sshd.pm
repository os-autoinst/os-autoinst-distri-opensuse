# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use testapi;

# check if sshd works
sub run() {
    my $self = shift;
    # new user to test sshd
    my $ssh_testman        = "sshboy";
    my $ssh_testman_passwd = "let3me2in1";

    select_console 'root-console';

    script_run('SuSEfirewall2 off');
    script_run('chkconfig sshd on');
    assert_script_run("chkconfig sshd on", 60);
    assert_script_run("rcsshd restart",    60);    # will do nothing if it is already running

    script_run('rcsshd status', 0);
    assert_screen 'test-sshd-1';

    # create a new user to test sshd
    my $changepwd = $ssh_testman . ":" . $ssh_testman_passwd;
    script_run("useradd -m $ssh_testman");
    script_run("echo $changepwd | chpasswd");
    $self->clear_and_verify_console;
    select_console 'user-console';

    # login use new user account
    script_run('ssh ' . $ssh_testman . '@localhost -t echo LOGIN_SUCCESSFUL', 0);
    assert_screen "ssh-login", 60;
    type_string "yes\n";
    sleep 3;
    type_string "$ssh_testman_passwd\n";
    assert_screen "ssh-login-ok", 10;
}

sub test_flags() {
    return {milestone => 1};
}

1;
# vim: set sw=4 et:
