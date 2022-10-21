# Copyright 2020-2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: PAM tests for pam-config, create, add or delete services
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#70345, poo#108096, tc#1767580

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';
use version_utils 'is_sle';

sub run {
    select_serial_terminal;

    # Create a simple Unix authentication configuration, all backup files will not be deleted
    if (!is_sle) {
        zypper_call 'in systemd-experimental';
    }
    assert_script_run 'pam-config --create', timeout => 180;
    if (is_sle) {
        assert_script_run 'ls /etc/pam.d | grep config-backup';
    }

    # Add new authentication methods ldap and ssh.
    # Based on bsc#1196896, pam_ldap is removed on SLE,
    # so we need skip it on SLE
    zypper_call('in nss-pam-ldapd') if (!is_sle);
    zypper_call('in pam_ssh');

    my @meth_list = ('ssh');
    push(@meth_list, 'ldap') if (!is_sle);
    foreach my $meth (@meth_list) {
        # Add a method
        assert_script_run "pam-config --add --$meth";
        assert_script_run "find /etc/pam.d -type f | grep common | xargs grep -E $meth";
        # Delete a method
        assert_script_run "pam-config --delete --$meth";
        validate_script_output "find /etc/pam.d -type f | grep common | xargs grep -E $meth || echo 'check pass'", sub { m/check pass/ };
    }

    # Upload logs
    if (is_sle) {
        upload_logs("/var/log/messages");
    }
    else {
        script_run("journalctl --no-pager -o short-precise > /tmp/full_journal.log");
        upload_logs "/tmp/full_journal.log";
    }
}

sub test_flags {
    return {always_rollback => 1};
}

sub post_fail_hook {
    assert_script_run 'cp -pr /mnt/pam.d /etc';
}

1;
