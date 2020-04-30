# SUSE's openQA tests
#
# Copyright © 2018-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

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
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base 'consoletest';
use testapi;
use strict;
use warnings;
use lockapi qw(barrier_create barrier_wait);
use utils 'zypper_call';

sub run {
    my $password = $testapi::password;
    select_console 'root-console';
    zypper_call 'in vsftpd expect';
    # export slenkins variables
    assert_script_run 'export SERVER=127.0.0.1';
    assert_script_run 'export CLIENT=127.0.0.1';
    # hosts entry for ssh-copy-id with expect
    assert_script_run 'echo "$SERVER server" >>/etc/hosts';
    assert_script_run 'echo "$CLIENT client" >>/etc/hosts';
    # copy ssh keys on server and client
    assert_script_run 'ssh-keygen -f /root/.ssh/id_rsa -N ""';
    assert_script_run "expect -c 'spawn ssh-copy-id client;expect \"yes\";send \"yes\\r\";expect \"Password\";send \"$password\\r\";interact'";
    assert_script_run "expect -c 'spawn ssh-copy-id server;expect \"yes\";send \"yes\\r\";interact'";
    assert_script_run "expect -c 'spawn ssh-copy-id 127.0.0.1;expect \"yes\";send \"yes\\r\";interact'";
    # extract vsftpd testsuite in /tmp/vsftpd
    assert_script_run 'cd /tmp';
    assert_script_run 'wget ' . data_url('qam/vsftpd.tar.gz');
    assert_script_run 'tar xzfv vsftpd.tar.gz';
    assert_script_run 'bash run.sh | tee run.log', 300;
    upload_logs('run.log');
}

1;
