# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: simple mysql server startup test
# - Install mysql
# - Check mysql service status
# - Start mysql
# - Check mysql service status
# Maintainer: Oliver Kurz <okurz@suse.de>

use strict;
use warnings;
use base "consoletest";
use testapi;
use utils;

sub run {
    select_console 'root-console';
    zypper_call('in mysql');
    systemctl 'status mysql', expect_false => 1, fail_message => 'mysql should be disabled by default';
    systemctl 'start mysql';
    systemctl 'status mysql';
    assert_screen 'test-mysql_srv-1';
}

1;
