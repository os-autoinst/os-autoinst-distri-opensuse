# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: tftp yast2-tftp-server
# Summary: this test checks that YaST's tftp-server module are
#          setup, enabled and disabled correctly in cmd mode.
# - Install yast2-tftp-server tftp
# - Setup tftp using directory as "/srv/tftpboot", enable directory listing
# - Enable tftp-server service
# - Adjust permissions and create a test file inside directory
# - Connect using tftp command, get test file and check
# - Connect using tftp command, put test file back
# - Cleanup
# Maintainer: Shukui Liu <skliu@suse.com>

use base 'y2_module_basetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    select_serial_terminal;
    zypper_call('in tftp yast2-tftp-server', timeout => 1200);
    assert_script_run 'yast tftp-server directory path=/srv/tftpboot';
    validate_script_output 'yast tftp-server directory list 2>&1', sub { m/tftpboot/ };
    assert_script_run 'yast tftp-server status enable';
    validate_script_output 'yast tftp-server status show 2>&1', sub { m/true/ };

    assert_script_run 'chmod 777 /srv/tftpboot';
    assert_script_run 'echo "hello world" > /srv/tftpboot/tmp.txt';
    assert_script_run 'chmod 777 /srv/tftpboot/tmp.txt';

    validate_script_output 'tftp -v 127.0.0.1 -c get tmp.txt 2>&1', sub { m/Received/ };
    validate_script_output 'cat tmp.txt 2>&1', sub { m/hello world/ };

    validate_script_output 'tftp -v 127.0.0.1 -c put tmp.txt 2>&1', sub { m/Sent/ };

    assert_script_run 'yast tftp-server status disable';
    validate_script_output 'yast tftp-server status show 2>&1', sub { m/false/ };
}

1;
