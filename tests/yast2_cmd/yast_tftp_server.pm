# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: yast tftp-server, list, set and show summary.
# Maintainer: shukui <skliu@suse.com>

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
    assert_script_run 'yast tftp-server status disable';
    validate_script_output 'yast tftp-server status show 2>&1', sub { m/false/ };
}
1;
