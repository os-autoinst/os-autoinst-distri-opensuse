# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: simple mysql server startup test
# Maintainer: Oliver Kurz <okurz@suse.de>

use strict;
use base "consoletest";
use testapi;
use utils;

sub run {
    select_console 'root-console';
    zypper_call('in mysql');
    assert_script_run '! systemctl status --no-pager mysql.service', fail_message => 'mysql should be disabled by default';
    assert_script_run 'systemctl start mysql.service';
    assert_script_run 'systemctl status --no-pager mysql.service';
    assert_screen 'test-mysql_srv-1';
}

1;
# vim: set sw=4 et:
