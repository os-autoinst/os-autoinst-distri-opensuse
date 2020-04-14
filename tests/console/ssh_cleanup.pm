# Copyright © 2016-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Cleanup ssh test user to prevent the user showing up in
#          displaymanager and confusing other tests
#          - If user sshboy exists, remove the user
#
# Maintainer: Oliver Kurz <okurz@suse.de>
# Tags: poo#65375

use base "consoletest";
use strict;
use warnings;
use testapi;

sub run {
    select_console 'root-console';
    assert_script_run('getent passwd sshboy > /dev/null && userdel -fr sshboy');
}

sub test_flags {
    return {milestone => 1, fatal => 0};
}

1;
