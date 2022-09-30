# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-Later
#
# Summary: Verify the "aulast" can print a list of the last logged-in users
# Maintainer: QE Security <none@suse.de>
# Tags: poo#81772, tc#1768581

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $audit_log = '/var/log/audit/audit.log';
    my $testfile = '/tmp/testfile';
    my $user = 'testuser';
    my $pwd = 'testpassw0rd';
    my $wrong_pwd = 'wrongpassw0rd';

    select_console 'root-console';
    zypper_call('in expect');

    # Check if audit service is active
    assert_script_run('systemctl restart auditd');

    # Create a test user for testing and clear the audit log
    assert_script_run("useradd -m $user");
    assert_script_run("echo $user:$pwd | chpasswd");
    assert_script_run("echo '' > $audit_log");

    # Let user login localhost and then log out
    assert_script_run(
        "expect -c 'spawn ssh -v -o StrictHostKeyChecking=no $user\@localhost; expect \"Password: \"; send \"$pwd\\n\"; expect \"~*\"; send \"exit\\n\"'"
    );

    # Run aulast to print last logged-in users
    validate_script_output('aulast', sub { m/$user/ });

    # Create a null test file
    assert_script_run("touch $testfile");

    # Print last logged-in users into test file
    assert_script_run("aulast -f $testfile");

    # Copy audit log to test file
    assert_script_run("cp $audit_log $testfile");

    # Run aulast -f testfile again to print last logged-in user
    validate_script_output("aulast -f $testfile", sub { m/$user/ });

    # Report bad logins
    assert_script_run('aulast --bad');

    # Let test user login localhost but fail it
    assert_script_run(
        "expect -c 'spawn ssh -v -o StrictHostKeyChecking=no $user\@localhost; expect \"Password: \"; send \"$wrong_pwd\"; exit'"
    );

    # Report bad login again, the bad login from test user should be recorded
    validate_script_output('aulast --bad', sub { m/$user/ });

    # Print out the audit event serial numbers
    validate_script_output("aulast --user $user --proof", sub { m/serial numbers/ });
}

1;
