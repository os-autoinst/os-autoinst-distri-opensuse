# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: this test checks that YaST2's tftp-server module are
#          setup, enabled and disabled correctly in gui mode.
# Maintainer: Shukui Liu <skliu@suse.com>

use base "y2_module_guitest";
use strict;
use warnings;
use testapi;

sub run {
    my $self = shift;

    select_console 'root-console';
    zypper_call('in tftp yast2-tftp-server', timeout => 1200);
    script_run 'systemctl status tftp.socket';

    select_console 'x11';
    $self->launch_yast2_module_x11('tftp-server', match_timeout => 60);
    send_key "alt-n";
    assert_screen "yast2_tftp_server_enabled";    # here is the tag name of the needle.
    send_key "alt-o";                             # OK => Exit

    select_console 'root-console';
    assert_script_run 'systemctl status tftp.socket';
    assert_screen "yast2_tftp_server_check_socket";
    assert_script_run 'chmod 777 /srv/tftpboot';
    assert_script_run 'echo "hello world" > /srv/tftpboot/tmp.txt';
    assert_script_run 'chmod 777 /srv/tftpboot/tmp.txt';
    assert_script_run 'tftp -v 127.0.0.1 -c get tmp.txt';
    assert_script_run 'tftp -v 127.0.0.1 -c put tmp.txt';
    assert_screen "yast2_tftp_server_result";
    select_console 'x11';
}

1;
