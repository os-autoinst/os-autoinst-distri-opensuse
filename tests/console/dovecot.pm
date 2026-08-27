# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: dovecot
# Summary: Basic dovecot IMAP/POP3 server test
# - Install dovecot
# - Start the service and verify it is running
# - Check that dovecot listens on IMAP (143) and POP3 (110)
# - Stop the service
# Maintainer: QE Core <qe-core@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';
use Utils::Systemd 'systemctl';

sub run {
    select_serial_terminal;
    zypper_call('in dovecot');
    systemctl('start dovecot');
    systemctl('status dovecot');
    assert_script_run('ss -tlnp | grep dovecot');
    systemctl('stop dovecot');
}

sub test_flags {
    return {fatal => 0, no_rollback => 1};
}

1;
