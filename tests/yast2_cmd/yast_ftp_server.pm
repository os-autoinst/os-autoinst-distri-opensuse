# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: yast2-ftp-server yast2-users
# Summary: this test checks "yast ftp-server" module.
#          this module configure ftp-server services in yast command line mode.
# - Install yast2-ftp-server and yast2-users
# - Enable SSL/TLS
# - Enable access for anonymous and authenticated users
# - Enable access permissions and upload for anonymous users
# - Set directory for anonymous users to /srv/ftp
# - Enable ftp chrooting
# - Set maximum idle time to 15 minutes
# - Enable saving log messages into the log file
# - Set maximum connected clients to 1500
# - Set maximum number of clients connected via IP to 20
# - Set maximum data transfer rate permitted for anonymous clients to 10000KB/s
# - Set maximum data transfer rate permitted for local authenticated users to
#   10000KB/s
# - Set start FTP daemon in the boot process
# - Set start FTP daemon manually
# - Set Start FTP daemon via systemd socket (SLE15+)
# - Set Start FTP daemon via xinetd (SLE12SP4)
# - Set FTP daemon mask as 177:077
# - Set welcome message is the text to display when someone connects to the
#   server as "hello everybody"
# - Disable saving log messages into the log file
# - Disable ftp chrooting
# - Disable SSL/TLS
# - Create a test file
# - Download test file via wget using ftp
# Maintainer: Shukui Liu <skliu@suse.com>

=head1 Create regression test for ftp-server and verify

Reference:
https://www.suse.com/documentation/sles-15/singlehtml/book_sle_admin/book_sle_admin.html#id-1.3.3.6.13.6.14

a)
    run various commands to configure ftp server.

b)
    run "yast ftp-server show", and using regular expression to
    check the configuration results.

c)
    This test script uncovers a bug #1142146, which results two soft-failures.

=cut


use base 'y2_module_basetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils 'is_sle';

sub run {
    my ($self) = @_;
    select_serial_terminal;
    zypper_call 'in yast2-ftp-server';
    zypper_call 'in yast2-users';

    #SSL, TLS
    assert_script_run 'yast ftp-server SSL enable';

    assert_script_run 'yast ftp-server TLS enable';

    #access
    assert_script_run 'yast ftp-server access anon_and_authen';

    #anon_access
    assert_script_run 'yast ftp-server anon_access can_upload';

    #anon_dir
    assert_script_run 'yast ftp-server anon_dir set_anon_dir=/srv/ftp';

    #chroot
    assert_script_run 'yast ftp-server chroot enable';

    #idle_time
    assert_script_run 'yast ftp-server idle_time set_idle_time=15';

    #logging
    assert_script_run 'yast ftp-server logging enable';

    #max_clients
    assert_script_run 'yast ftp-server max_clients set_max_clients=1500';

    #max_clients_ip
    assert_script_run 'yast ftp-server max_clients_ip set_max_clients=20';

    #max_rate_anon
    assert_script_run 'yast ftp-server max_rate_anon set_max_rate=10000';

    #max_rate_authen
    assert_script_run 'yast ftp-server max_rate_authen set_max_rate=10000';

    #port_range
    assert_script_run 'yast ftp-server port_range set_min_port=20000 set_max_port=30000';

    #startup: atboot, manual, socket
    assert_script_run 'yast ftp-server startup atboot';
    assert_script_run 'yast ftp-server startup manual';
    if (is_sle('15+')) {
        assert_script_run 'yast ftp-server startup socket';
    }
    if (is_sle('<=12-sp5')) {
        assert_script_run 'yast ftp-server startup xinetd';
    }

    assert_script_run 'yast ftp-server startup manual';

    #umask
    assert_script_run 'yast ftp-server umask set_umask=177:077';

    #welcome_message
    assert_script_run 'yast ftp-server welcome_message set_message="hello everybody" ';

    #show, displays FTP server settings.
    my @pattern = ('Start-Up:FTP daemon',
        'hello everybody',
        'Create directories disabled');

    my $output;
    if (is_sle('<=12-sp2')) {
        $output = script_output("yast ftp-server show 2>&1", proceed_on_failure => 1);
        record_soft_failure 'known bug bsc#1143193, "yast ftp-server show" should not exit with code 16';
    } else {
        $output = script_output("yast ftp-server show 2>&1");
    }

    foreach my $item (@pattern) {
        $output =~ m#$item#i || die "Expected text \"$item\" not shown";
    }

    assert_script_run 'yast ftp-server logging disable';
    assert_script_run 'yast ftp-server chroot disable';
    assert_script_run 'yast ftp-server SSL disable';
    assert_script_run 'yast ftp-server TLS disable';

    #ensure that the ftp server is actually working.
    if (is_sle('15+')) {
        assert_script_run 'yast ftp-server startup socket';
    }
    if (is_sle('<=12-sp5')) {
        assert_script_run 'yast ftp-server startup xinetd';
    }
    assert_script_run 'echo "hello world" > /srv/ftp/tmp.txt';
    assert_script_run 'wget ftp://127.0.0.1:/tmp.txt';
    validate_script_output 'cat tmp.txt 2>&1', sub { m/hello world/ };
    assert_script_run 'rm -f tmp.txt';
}

1;
