# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test ssh with krb5 authentication - server
# Maintainer: QE Security <none@suse.de>
# Ticket: poo#51560, poo#51566

use base "consoletest";
use testapi;
use utils;
use lockapi;
use mmapi;
use version_utils qw(is_sle);
use krb5crypt;    # Import public variables
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;
    assert_script_run("source /etc/profile.d/krb5.sh") if is_sle('<16');
    assert_script_run "kadmin -p $adm -w $pass_a -q 'addprinc -pw $pass_t $tst'";
    assert_script_run "useradd -m $tst";

    # Config sshd
    foreach my $i ('GSSAPIAuthentication', 'GSSAPICleanupCredentials') {
        if (is_sle('>=16')) {
            assert_script_run "echo $i yes >> /etc/ssh/sshd_config.d/10-gssapi.conf";
            assert_script_run "echo Port 2222 >> /etc/ssh/sshd_config.d/10-gssapi.conf";
            assert_script_run "semanage port -a -t ssh_port_t -p tcp 2222" if (script_run("selinuxenabled") == 0);
        } else {
            assert_script_run "sed -i 's/^#$i .*\$/$i yes/' /etc/ssh/sshd_config";
            assert_script_run "echo Port 2222 >> /etc/ssh/sshd_config";
        }
    }

    systemctl("restart sshd");

    # signal the client we are ready
    barrier_wait('KRB5_SSH_SERVER_READY');
    barrier_wait('KRB5_SSH_TEST_DONE');
}

sub test_flags {
    return {fatal => 1};
}


1;
