# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use strict;
use testapi;

# Summary: Cleanup ssh test user to prevent the user showing up in
#  displaymanager and confusing other tests
# Maintainer: okurz@suse.de
sub run() {
    select_console 'root-console';
    assert_script_run('getent passwd sshboy > /dev/null && userdel -fr sshboy');
}

1;
# vim: set sw=4 et:
