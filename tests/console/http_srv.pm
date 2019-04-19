# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Simple apache server test
# Maintainer: Oliver Kurz <okurz@suse.de>

use strict;
use warnings;
use base "consoletest";
use testapi;
use utils;
use version_utils 'is_sle';

sub run {
    select_console 'root-console';
    # Log space available before installation, see poo#19834
    script_run("df -h > /dev/$serialdev", 0);
    # In upgrade scenario we have service_check module and apache2 already installed
    if (((get_var('UPGRADE') == 1) || get_var('MIGRATION_METHOD')) && is_sle) {
        zypper_call("rm apache2");
    }
    # Install apache2
    zypper_call("in apache2");
    # After installation, apache2 is disabled
    systemctl 'show -p UnitFileState apache2.service|grep UnitFileState=disabled';

    # let's try to run it
    systemctl 'start apache2.service';
    systemctl 'show -p ActiveState apache2.service|grep ActiveState=active';
    systemctl 'show -p SubState apache2.service|grep SubState=running';

    # verify httpd serves index.html
    type_string "echo Lorem ipsum dolor sit amet > /srv/www/htdocs/index.html\n";
    assert_script_run(
        "curl -f http://localhost/ | grep 'Lorem ipsum dolor sit amet'",
        timeout      => 90,
        fail_message => 'Could not access local apache2 instance'
    );
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;
    select_console('log-console');
    # Log disk usage if test failed, see poo#19834
    script_run("df -h > /dev/$serialdev", 0);

}

1;
