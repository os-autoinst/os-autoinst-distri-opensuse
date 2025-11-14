# SUSE's openQA tests
#
# Copyright 2018-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: vsftpd expect
# Summary: vsftpd QAM regression testsuite
#          not testing SSL now due to https://bugzilla.suse.com/show_bug.cgi?id=1116571
# - If system is server, create a lock ("barrier") for sshd service
#   - Install vsftpd
#   - Otherwise, install expect
# - Add hostnames to /etc/hosts
# - Generate ssh keys
# - Unlock sshd barrier
# - Copy ssh keys to server and client using "ssh-copy-id" using expect in
# interactive mode
# - Get vsftpd testsuite and uncompress on /tmp
# - Create a lock for vsftpd suite
# - If HOSTNAME contains "client", run "run.sh" script
# - Unlock vsftpd barrier
# Maintainer: QE Core <qe-core@suse.de>

use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';
use Utils::Architectures;
use version_utils 'has_selinux';

sub run {
    select_serial_terminal;

    zypper_call 'in vsftpd expect';

    # Allow full FTP access when enable selinux
    assert_script_run 'setsebool -P ftpd_full_access on' if has_selinux;
    # export slenkins variables
    assert_script_run 'export SERVER=127.0.0.1';
    assert_script_run 'export CLIENT=127.0.0.1';
    # hosts entry for ssh-copy-id with expect
    assert_script_run 'echo "$SERVER server" >>/etc/hosts';
    assert_script_run 'echo "$CLIENT client" >>/etc/hosts';
    # extract vsftpd testsuite in /tmp/vsftpd
    assert_script_run 'cd /tmp';
    assert_script_run 'wget ' . data_url('qam/vsftpd.tar.gz');
    assert_script_run 'tar xzfv vsftpd.tar.gz';
    if (is_s390x) {
        record_info("bsc#1176813", "vsftpd: security: one_process_model needs a better OS for the anonymous user scenarios");
        assert_script_run 'bash run_s390x.sh |& tee run.log', 300;
    } else {
        assert_script_run 'bash run.sh |& tee run.log', 300;
    }
    upload_logs('run.log');
}

sub post_fail_hook {
    my ($self) = @_;
    upload_logs('run.log');
    $self->SUPER::post_fail_hook;
}

1;
