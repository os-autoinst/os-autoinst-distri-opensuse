# Copyright (C) 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check for MTAs
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console 'root-console';

    assert_script_run '! rpm -q exim';

    # check if postfix is installed, enabled and running
    assert_script_run 'rpm -q postfix';
    systemctl 'is-enabled postfix';
    systemctl 'is-active postfix';
    systemctl 'status postfix';

    # test email transmission
    assert_script_run 'echo "FOOBAR123" | mail root';
    assert_script_run 'postqueue -p';
    script_run 'cat /var/mail/root';
    assert_script_run 'grep FOOBAR123 /var/mail/root';
}

1;

