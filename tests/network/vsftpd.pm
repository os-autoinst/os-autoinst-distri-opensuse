# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: vsftpd QAM regression testsuite
#          not testing SSL now due to https://bugzilla.suse.com/show_bug.cgi?id=1116571
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base 'consoletest';
use testapi;
use strict;
use lockapi qw(barrier_create barrier_wait);
use utils 'zypper_call';

sub run {
    select_console 'root-console';
    if (check_var('HOSTNAME', 'server')) {
        zypper_call 'in vsftpd';
    }
    # export slenkins variables
    assert_script_run 'export SERVER=10.0.2.101';
    assert_script_run 'export CLIENT=10.0.2.102';
    # copy ssh keys on server and client
    assert_script_run 'ssh-keygen -f /root/.ssh/id_rsa -N ""';
    type_string "ssh-copy-id -o StrictHostKeyChecking=no \$SERVER\n";
    wait_still_screen 3;
    type_password;
    send_key 'ret';
    wait_still_screen 3;
    type_string "ssh-copy-id -o StrictHostKeyChecking=no \$CLIENT\n";
    wait_still_screen 3;
    type_password;
    send_key 'ret';
    wait_still_screen 3;
    # extract vsftpd testsuite in /tmp/vsftpd
    assert_script_run 'cd /tmp';
    assert_script_run 'wget ' . data_url('qam/vsftpd.tar.gz');
    assert_script_run 'tar xzfv vsftpd.tar.gz';
    barrier_wait('VSFTPD_SUITE_READY');
    if (check_var('HOSTNAME', 'client')) {
        assert_script_run 'bash run.sh', 300;
    }
    barrier_wait('VSFTPD_FINISHED');
}

1;
