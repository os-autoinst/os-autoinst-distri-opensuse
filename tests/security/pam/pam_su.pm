# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: PAM tests for su, su to root should fail if user is not in group "wheel"
# Maintainer: rfan1 <richard.fan@suse.com>
# Tags: poo#70345, tc#1167579

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use base 'consoletest';
use utils 'clear_console';

sub run {
    select_console 'root-console';

    # User will not be able to su to root since it is not belong to group "wheel"
    my $user   = 'bernhard';
    my $passwd = 'nots3cr3t';
    my $group  = 'wheel';
    validate_script_output "id $user | grep $group || echo 'check pass'", sub { m/check pass/ };

    # Modify the PAM configuration files
    my $su_file      = '/etc/pam.d/su';
    my $su_file_bak  = '/tmp/su';
    my $sul_file     = '/etc/pam.d/su-l';
    my $sul_file_bak = '/tmp/su-l';
    assert_script_run "cp $su_file $su_file_bak";
    assert_script_run "cp $sul_file $sul_file_bak";
    assert_script_run "sed -i '\$a auth     required       pam_wheel.so use_uid' $su_file";
    assert_script_run "sed -i '\$a auth     required       pam_wheel.so use_uid' $sul_file";
    upload_logs($su_file);
    upload_logs($sul_file);

    # Switch to user console
    clear_console;
    select_console 'user-console';

    # Then su to root should fail
    assert_script_run "expect -c 'spawn su - root; \\
expect \"Password: \"; send \"$passwd\\n\"; \\
expect {
    \"*Permission denied\" {
      exit 0
   }
   eof {
       exit 1
   }
}'";

    # Make sure your current user "suse"
    validate_script_output "whoami | grep $user && echo 'check pass'", sub { m/check pass/ };
    # Tear down, clear the pam configuration changes
    clear_console;
    select_console 'root-console';
    assert_script_run "mv $su_file_bak $su_file";
    assert_script_run "mv $sul_file_bak $sul_file";
}

sub test_flags {
    return {always_rollback => 1};
}

sub post_fail_hook {
    select_console 'root-console';
    assert_script_run 'cp -pr /mnt/pam.d /etc';
}

1;
