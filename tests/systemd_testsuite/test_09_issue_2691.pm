# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run test executed by TEST-09-ISSUE-2691 from upstream after openSUSE/SUSE patches.
# Maintainer: Sergio Lindo Mansilla <slindomansilla@suse.com>, Thomas Blume <tblume@suse.com>

use base "consoletest";
use warnings;
use strict;
use testapi;
use utils 'zypper_call';
use power_action_utils 'power_action';

sub run {
    #prepare test
    assert_script_run 'cd /var/opt/systemd-tests';
    assert_script_run './run-tests.sh TEST-09-ISSUE-2691 --setup 2>&1 | tee /tmp/testsuite.log', 600;
    assert_script_run 'ls -l /etc/systemd/system/testsuite.service';
    assert_script_run 'ls -l /usr/lib/systemd/system-shutdown/debug.sh';
    #reboot
    power_action('reboot', keepconsole => 1, textmode => 1);
    #login
    send_key_until_needlematch('text-login', 'ret', 360, 5);
    type_string "root\n";
    assert_screen "password-prompt";
    type_password;
    send_key('ret');
    assert_screen "text-logged-in-root";
    # run test
    type_string 'systemctl start testsuite.service';
    send_key 'ret';
    type_string 'systemctl status testsuite.service';
    send_key 'ret';
    #this test run needs a reboot
    power_action('reboot', keepconsole => 1, textmode => 1);
    wait_still_screen 20;
    #login
    send_key_until_needlematch('text-login', 'ret', 360, 5);
    type_string "root\n";
    assert_screen("password-prompt");
    type_password;
    send_key('ret');
    assert_screen "text-logged-in-root";
    assert_script_run 'cd /var/opt/systemd-tests';
    assert_script_run 'ls -l /shutdown-log.txt';
    assert_script_run './run-tests.sh TEST-09-ISSUE-2691 --run 2>&1 | tee /tmp/testsuite.log', 60;
    assert_screen("systemd-testsuite-test-09-issue-2691");
}

sub test_flags {
    return { always_rollback => 1 };
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;
    assert_script_run('tar -cjf TEST-09-ISSUE-2691-logs.tar.bz2 /var/opt/systemd-tests/logs/ /shutdown-log.txt');
    upload_logs('TEST-09-ISSUE-2691-logs.tar.bz2');
}


1;
