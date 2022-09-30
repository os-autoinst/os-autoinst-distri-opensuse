# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-Later
#
# Summary: Verify the "aulastlog" can print the last login for all users of a machine similar to the way lastlog does
#          The login name, port and last login time will be printed
# Maintainer: QE Security <none@suse.de>
# Tags: poo#81772, tc#1768580

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $audit_log = '/var/log/audit/audit.log';
    my $user = 'suse';
    my $pwd = 'testpassw0rd';

    select_console 'root-console';

    # Restart auditd, since auditd is stopped in the previous case
    assert_script_run('systemctl restart auditd');

    # Run aulastlog directly
    assert_script_run('aulastlog');

    # Print the lastlog record for user with specific login only
    assert_script_run('aulastlog -u root');

    # Creat a new user 'suse'
    zypper_call('in expect');
    assert_script_run("useradd -m $user");
    assert_script_run("echo $user:$pwd | chpasswd");

    # Print the lastlog record of user 'suse', this new user has not logged in right now
    validate_script_output("aulastlog -u $user", sub { m/Never logged in/ });

    # Let user 'suse' login localhost and then log out
    assert_script_run(
        "expect -c 'spawn ssh $user\@localhost; expect \"Password: \"; send \"$pwd\\n\"; expect \"~*\"; send \"exit\\n\"'"
    );

    # Print the lastlog record of user 'suse' again while checking username and timestamp in output
    validate_script_output("aulastlog -u $user", sub { m/suse.*[0-9]{2}\/[0-9]{2}\/\d+ [0-9]{2}:[0-9]{2}:[0-9]{2}/ });

    # Use stdin as the source of audit records while checking username and timestamp in output
    validate_script_output("cat $audit_log | aulastlog --stdin -u $user", sub { m/suse.*[0-9]{2}\/[0-9]{2}\/\d+ [0-9]{2}:[0-9]{2}:[0-9]{2}/ });
}

1;
