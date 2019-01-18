# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: client part of mariadb ssl connection test
# Maintainer: Wei Jiang <wjiang@suse.com>
# Tags: TC1595192

use base "consoletest";
use strict;
use warnings;
use testapi;
use lockapi;
use utils;
use mm_tests;

sub run {
    select_console 'root-console';
    configure_static_network('10.0.2.11/24');
    zypper_call('in mariadb-client');

    mutex_lock('mariadb');
    mutex_unlock('mariadb');

    type_string_slow "mysql --ssl --host=10.0.2.1 --user=root --password\n";
    assert_screen 'mariadb-monitor-password';
    type_string_slow "suse\n";
    # Give more time to authenticate and open the db server
    assert_screen 'mariadb-monitor-opened', 60;
    type_string_slow "quit\n";
}

1;
