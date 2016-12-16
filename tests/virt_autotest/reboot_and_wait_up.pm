# SUSE's openQA tests
#
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
package reboot_and_wait_up;
# Summary: virt_autotest: the initial version of virtualization automation test in openqa, with kvm support fully, xen support not done yet
# Maintainer: alice <xlai@suse.com>

use strict;
use warnings;
use testapi;
use login_console;
use base "proxymode";

sub reboot_and_wait_up() {
    my $self           = shift;
    my $reboot_timeout = shift;

    wait_idle 1;
    select_console('root-console');
    if (get_var("PROXY_MODE")) {
        my $test_machine = get_var("TEST_MACHINE");
        $self->reboot($test_machine, $reboot_timeout);
    }
    else {
        wait_idle 1;
        type_string("/sbin/reboot\n");
        wait_idle 1;
        reset_consoles;
        wait_idle 1;
        &login_console::login_to_console($reboot_timeout);
    }
}

1;

