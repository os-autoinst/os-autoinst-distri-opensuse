# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: PAM tests for faillock, the uesr login can be locked
#          if reaches the limit number of authentication failures;
#          we can unlock it as well with root user.
# Maintainer: QE Security <none@suse.de>
# Tags: poo#102990 tc#1769824

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use base 'consoletest';
use utils 'zypper_call';
use version_utils 'is_sle';

sub run {
    select_console('root-console');
    zypper_call('in expect');

    my $user_name = 'pamtest';
    my $user_pw = $testapi::password;
    my $bad_pw = 'badpassword';
    assert_script_run("useradd -m $user_name");
    assert_script_run("echo $user_name:$user_pw | chpasswd");

    # Package change log check on SLE: jsc#sle-20638
    validate_script_output('rpm -q pam --changelog', sub { m/jsc#sle-20638/ }) if (is_sle);

    # Basic function test, lock&unlock
    # Modify the pam configuration files
    my $pam_config = <<EOF;
auth       required        pam_faillock.so preauth deny=3 unlock_time=600
auth       required        pam_faillock.so authfail deny=3 unlock_time=600
account    required        pam_faillock.so
EOF
    assert_script_run('cp /etc/pam.d/common-auth /etc/pam.d/common-auth.back');
    assert_script_run('cp /etc/pam.d/common-password /etc/pam.d/common-password.back');
    assert_script_run("echo '$pam_config' >> /etc/pam.d/common-auth");
    assert_script_run("echo '$pam_config' >> /etc/pam.d/common-password");

    # After 3 failed login, the user will be locked
    assert_script_run(
        "expect -c '
    spawn ssh $user_name\@localhost
    expect {
        {continue} { send \"yes\\r\"; exp_continue }
    {assword} { send \"$bad_pw\\r\" }
    }
    expect {
        {denied} { exp_continue }
        {assword} { send \"$bad_pw\\r\" }
    }
    expect {
        {denied} { exp_continue }
        {assword} { send \"$bad_pw\\r\" }
    }
    expect {
        {denied} { exp_continue }
        {assword} { send \"$bad_pw\\r\" }
    }
    expect -nocase {denied} { close; wait }'"
    );

    assert_script_run(
        "expect -c '
    spawn ssh $user_name\@localhost
    expect {
        {continue} { send \"yes\\r\"; exp_continue }
    {assword} { send \"$user_pw\\r\" }
    }
    expect -nocase {The account is locked due to 3 failed logins} { close; wait }'"
    );

    # Check the syslog can record the lock operation
    assert_script_run("journalctl -a | grep 'pam_faillock.*$user_name account temporarily locked'");

    # Unlock the user, then we can login to the host
    assert_script_run("faillock --user $user_name --reset");
    assert_script_run(
        "expect -c '
    spawn ssh $user_name\@localhost
    expect {
        {continue} { send \"yes\\r\"; exp_continue }
    {assword} { send \"$user_pw\\r\" }
    }
    expect {$user_name\@\$HOSAME} { send \"exit\\r\" }'"
    );

    # Clean up
    assert_script_run('mv /etc/pam.d/common-auth.back /etc/pam.d/common-auth');
    assert_script_run('mv /etc/pam.d/common-password.back /etc/pam.d/common-password');
    assert_script_run("userdel -r $user_name");
}

sub test_flags {
    return {always_rollback => 1};
}

1;
