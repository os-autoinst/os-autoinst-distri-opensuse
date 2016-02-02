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
    assert_script_run "zypper -n -q in apache2";

    # After installation, apache2 is disabled
    assert_script_run "systemctl show -p UnitFileState apache2.service|grep UnitFileState=disabled";

    # let's try to run it
    assert_script_run "systemctl start apache2.service";
    assert_script_run "systemctl show -p ActiveState apache2.service|grep ActiveState=active";
    assert_script_run "systemctl show -p SubState apache2.service|grep SubState=running";

    # verify httpd serves index.html
    type_string "echo Lorem ipsum dolor sit amet > /srv/www/htdocs/index.html\n";
    assert_script_run "curl -f http://localhost/ | grep 'Lorem ipsum dolor sit amet'";
}

1;
# vim: set sw=4 et:
