# Copyright 2020-2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: PAM tests for su, su to root should fail if user is not in group "wheel"
# Maintainer: QE Security <none@suse.de>
# Tags: poo#70345, poo#106020, tc#1167579

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use base 'consoletest';
use utils qw(clear_console ensure_serialdev_permissions);
use Utils::Architectures;
use version_utils;

sub run {
    select_console 'root-console';

    # User will not be able to su to root since it is not belong to group "wheel"
    my $user = $testapi::username;
    my $passwd = $testapi::password;
    my $group = 'wheel';
    validate_script_output "id $user | grep $group || echo 'check pass'", sub { m/check pass/ };

    # Modify the PAM configuration files
    my $su_file_tw = '';
    my $sul_file_tw = '';
    my $su_file = '/etc/pam.d/su';
    my $sul_file = '/etc/pam.d/su-l';
    if (is_sle || is_leap) {
        $su_file_tw = '/usr/etc/pam.d/su';
        $sul_file_tw = '/usr/etc/pam.d/su-l';
    } else {
        $su_file_tw = '/usr/lib/pam.d/su';
        $sul_file_tw = '/usr/lib/pam.d/su-l';
    }
    my $su_file_bak = '/tmp/su';
    my $sul_file_bak = '/tmp/su-l';
    my $ret_su = script_run("[[ -e $su_file ]]");
    my $ret_sul = script_run("[[ -e $sul_file ]]");
    if ($ret_su != 0) {
        script_run "cp $su_file_tw $su_file";
    }
    if ($ret_sul != 0) {
        script_run "cp $sul_file_tw $sul_file";
    }
    assert_script_run "cp $su_file $su_file_bak";
    assert_script_run "cp $sul_file $sul_file_bak";
    assert_script_run "sed -i '\$a auth     required       pam_wheel.so use_uid' $su_file";
    assert_script_run "sed -i '\$a auth     required       pam_wheel.so use_uid' $sul_file";
    upload_logs($su_file);
    upload_logs($sul_file);

    clear_console;

    # On s390x platform, make sure that non-root user has
    # permissions for $serialdev to get openQA work properly.
    # Please refer to bsc#1195620
    ensure_serialdev_permissions if (is_s390x);

    # Switch to user console
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

    # Make sure the current user is not root
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
