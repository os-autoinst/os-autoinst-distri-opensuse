# Copyright 2018-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check for MTAs
# - Check if exim is not installed
# - Check if postfix is installed, enabled and running
# - Test email transmission
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils;

sub run {
    select_serial_terminal;

    assert_script_run '! rpm -q exim';
    if ((is_sle('<16') || is_leap('<16')) && !is_public_cloud) {
        # check if postfix is installed, enabled and running
        assert_script_run 'rpm -q postfix';
        systemctl 'is-enabled postfix';
        script_retry 'systemctl is-active postfix', retry => 3, delay => 10;
        systemctl 'status postfix';
    } else {
        # Install and start postfix on Public Cloud/SlE 16+/Leap 16+ and Tumbleweed
        zypper_call('in postfix mailx');
        systemctl 'enable postfix';
        systemctl 'start postfix';
    }

    record_info 'send email', 'send e-mail to a local user and check that it was delivered';
    assert_script_run 'echo "FOOBAR123" | mail root';
    assert_script_run 'postqueue -p';
    assert_script_run 'until postqueue -p|grep "Mail queue is empty";do sleep 1;done';
    assert_script_run 'grep FOOBAR123 /var/mail/root';

    record_info 'send bad email', 'send e-mail to a non-existent local user and check that it was bounced';
    assert_script_run 'echo "FOOBAR456" | mail agent_smith';
    assert_script_run 'postqueue -p';
    assert_script_run 'until postqueue -p|grep "Mail queue is empty";do sleep 1;done';
    assert_script_run 'grep "^Subject: Undelivered Mail Returned to Sender" /var/mail/root';
    assert_script_run 'journalctl -n1000 | grep "unknown user: \"agent_smith\""';

    record_info 'send attachement', 'Send mail with attachment';
    assert_script_run 'echo > /var/mail/root';
    assert_script_run 'dd bs=1024 count=10 if=/dev/urandom of=/tmp/foo';
    assert_script_run 'date | mail -a /tmp/foo -s "mail with attachement" root';
    assert_script_run 'postqueue -p';
    assert_script_run 'until postqueue -p|grep "Mail queue is empty";do sleep 1;done';
    assert_script_run 'grep "^Subject: mail with attachement" /var/mail/root';
    assert_script_run 'echo w1 | mail';
    assert_script_run 'diff foo /tmp/foo';

    record_info 'aliases', 'send e-mail to alias';
    assert_script_run 'newaliases';
    assert_script_run 'echo > /var/mail/root';
    assert_script_run 'echo "FOOBAR123" | mail nobody';
    assert_script_run 'postqueue -p';
    assert_script_run 'until postqueue -p|grep "Mail queue is empty";do sleep 1;done';
    assert_script_run 'grep FOOBAR123 /var/mail/root';
}

1;
