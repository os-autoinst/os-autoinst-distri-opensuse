# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-Later
#
# Summary: Verify the "aulastlog" can print the last login for all users of a
#          machine similar to the way lastlog does.
#          The login name, port and last login time will be printed.
# Maintainer: QE Security <none@suse.de>
# Tags: poo#81772, tc#1768580

use Mojo::Base 'opensusebasetest';
use testapi;
use utils;
use package_utils 'install_package';
use version_utils 'is_tumbleweed';

# Use a dedicated user: other modules already create shared users such as
# "suse", so reusing that name breaks in a full schedule.
my $user = 'aulastlog_user';
my $pwd = 'Hello-World';

sub run {
    my $audit_log = '/var/log/audit/audit.log';
    my $audit_service = 'auditd';

    select_console 'root-console';

    # Restart auditd, since auditd is stopped in the previous case
    assert_script_run("systemctl restart $audit_service");

    # Run aulastlog directly
    assert_script_run('aulastlog');

    # Print the lastlog record for user with specific login only
    assert_script_run('aulastlog -u root');

    # Create a dedicated user for this test. Remove leftovers from a failed
    # previous run first so the module stays repeatable.
    install_package('expect', trup_reboot => 1);
    script_run("userdel -r $user");
    assert_script_run("useradd -d /home/$user -m $user");
    assert_script_run("echo $user:$pwd | chpasswd");

    # Print the lastlog record of the new user, who has not logged in yet
    validate_script_output("aulastlog -u $user", sub { m/Never logged in/ });

    # Let the user log in to localhost and then log out
    assert_script_run(
        "expect -c 'spawn ssh $user\@localhost; expect \"Password: \"; send \"$pwd\\n\"; expect \"~*\"; send \"exit\\n\"'"
    );

    # Print the lastlog record again while checking username and timestamp
    validate_script_output("aulastlog -u $user", sub { m/$user.*[0-9]{2}\/[0-9]{2}\/\d+ [0-9]{2}:[0-9]{2}:[0-9]{2}/ });

    # Use stdin as the source of audit records while checking username and timestamp
    validate_script_output("cat $audit_log | aulastlog --stdin -u $user", sub { m/$user.*[0-9]{2}\/[0-9]{2}\/\d+ [0-9]{2}:[0-9]{2}:[0-9]{2}/ });
}

sub cleanup {
    script_run("userdel -r $user", timeout => 60);
}

sub post_run_hook {
    my $self = shift;
    $self->cleanup();
    $self->SUPER::post_run_hook;
}

sub post_fail_hook {
    my $self = shift;
    $self->cleanup();
    $self->SUPER::post_fail_hook;
}

1;
