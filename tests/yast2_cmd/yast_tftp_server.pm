# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: this test checks that YaST's tftp-server module are
#          setup, enabled and disabled correctly in cmd mode.
# Maintainer: Shukui Liu <skliu@suse.com>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console 'root-console';
    zypper_call('in tftp yast2-tftp-server', timeout => 1200);
    assert_script_run 'yast tftp-server directory path=/srv/tftpboot';
    validate_script_output 'yast tftp-server directory list 2>&1', sub { m/tftpboot/ };
    assert_script_run 'yast tftp-server status enable';
    validate_script_output 'yast tftp-server status show 2>&1', sub { m/true/ };

    assert_script_run 'chmod 777 /srv/tftpboot';
    assert_script_run 'echo "hello world" > /srv/tftpboot/tmp.txt';
    assert_script_run 'chmod 777 /srv/tftpboot/tmp.txt';

    validate_script_output 'tftp -v 127.0.0.1 -c get tmp.txt 2>&1', sub { m/Received/ };
    validate_script_output 'cat tmp.txt 2>&1',                      sub { m/hello world/ };

    validate_script_output 'tftp -v 127.0.0.1 -c put tmp.txt 2>&1', sub { m/Sent/ };

    assert_script_run 'yast tftp-server status disable';
    validate_script_output 'yast tftp-server status show 2>&1', sub { m/false/ };
}

1;
