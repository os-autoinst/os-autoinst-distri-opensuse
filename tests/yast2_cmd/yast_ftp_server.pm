# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.
#
# Summary: this test checks "yast ftp-server" module.
#          this module configure ftp-server services in yast command line mode.
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


use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';

sub run {
    select_console 'root-console';
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
    if (is_sle('<=12-sp4')) {
        assert_script_run 'yast ftp-server startup xinetd';
    }

    assert_script_run 'yast ftp-server startup manual';

    #umask
    assert_script_run 'yast ftp-server umask set_umask=177:077';

    #welcome_message
    assert_script_run 'yast ftp-server welcome_message set_message="hello everybody" ';

    #show, displays FTP server settings.
    my @pattern = ('Start-Up:FTP daemon needs manual starting',
        'hello everybody',
        'Anonymous and Authenticated Users');

    my $output = script_output "yast ftp-server show 2>&1";
    foreach my $item (@pattern) {
        if ($item eq 'hello everybody') {
            $output =~ m#$item#i || die '"yast ftp-server show" message error';
        } else {
            $output =~ m#$item#i || record_soft_failure 'known bug bsc#1142146, "yast ftp-server show" message error';
        }
    }

    assert_script_run 'yast ftp-server logging disable';
    assert_script_run 'yast ftp-server chroot disable';
    assert_script_run 'yast ftp-server SSL disable';
    assert_script_run 'yast ftp-server TLS disable';

    #ensure that the ftp server is actually working.
    if (is_sle('15+')) {
        assert_script_run 'yast ftp-server startup socket';
    }
    if (is_sle('<=12-sp4')) {
        assert_script_run 'yast ftp-server startup xinetd';
    }
    assert_script_run 'echo "hello world" > /srv/ftp/tmp.txt';
    assert_script_run 'wget ftp://127.0.0.1:/tmp.txt';
    validate_script_output 'cat tmp.txt 2>&1', sub { m/hello world/ };
}

1;
