# Copyright (C) 2018-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check for MTAs
# - Check if exim is not installed
# - Check if postfix is installed, enabled and running
# - Test email transmission
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    assert_script_run '! rpm -q exim';

    unless (get_var('PUBLIC_CLOUD')) {
        # check if postfix is installed, enabled and running
        assert_script_run 'rpm -q postfix';
        systemctl 'is-enabled postfix';
        systemctl 'is-active postfix';
        systemctl 'status postfix';
    } else {
        # Install and start postfix on Public Cloud
        zypper_call 'in postfix mailx';
        systemctl 'start postfix';
    }

    # test email transmission
    assert_script_run 'echo "FOOBAR123" | mail root';
    assert_script_run 'postqueue -p';
    assert_script_run 'until postqueue -p|grep "Mail queue is empty";do sleep 1;done';
    assert_script_run 'grep FOOBAR123 /var/mail/root';
}

1;

