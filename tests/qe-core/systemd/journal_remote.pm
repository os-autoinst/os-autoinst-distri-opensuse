# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: systemd-journal-remote
# Summary: - Send logs via systemd-journal-upload
#          - Collect them back via systemd-journal-remote
#          - Done on single machine and using https
# Maintainer: qe-core@suse.de

use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_sle);

sub run {

    select_serial_terminal;
    zypper_call("in systemd-journal-remote");
    # Test file comes from https://github.com/systemd/systemd/blob/24cc5082f6e4b6cacaa48e317c6501c3b739c7c7/test/units/TEST-04-JOURNAL.journal-remote.sh
    assert_script_run 'wget --quiet ' . data_url('qe-core/systemd/journal_remote.sh');
    assert_script_run 'chmod +x journal_remote.sh';
    if (is_sle('>=16.0')) {
        assert_script_run('semanage fcontext -a -t cert_t "/run/systemd/remote-pki(/.*)?"');
        assert_script_run('semanage fcontext -a -t cert_t "/run/systemd/journal-remote-tls(/.*)?"');
    }
    assert_script_run "./journal_remote.sh", 360;
}

sub post_run_hook {
    if (is_sle('>=16.0')) {
        assert_script_run('semanage fcontext -d "/run/systemd/remote-pki(/.*)?"');
        assert_script_run('semanage fcontext -d "/run/systemd/journal-remote-tls(/.*)?"');
    }
}
1;
