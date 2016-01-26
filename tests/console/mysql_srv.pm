# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use strict;
use base "consoletest";
use testapi;

sub run() {
    my $self = shift;

    select_console 'root-console';

    # Install apache2
    script_run "zypper -n -q in mysql", 10;

    # After installation, mysql is disabled
    script_run "systemctl status mysql.service | tee /dev/$serialdev -", 0;
    wait_serial(".*inactive.*", 4) || die "mysql should be disabled by default";

    # Now must be enabled
    script_run "systemctl start mysql.service",                          10;
    script_run "systemctl status mysql.service | tee /dev/$serialdev -", 0;
    wait_serial(".*Syntax error.*", 2, 1) || die "have error while starting mysql";

    assert_screen 'test-mysql_srv-1', 3;
}

1;
# vim: set sw=4 et:
