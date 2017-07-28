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

sub reboot_and_wait_up {
    my $self           = shift;
    my $reboot_timeout = shift;

    if (get_var("PROXY_MODE")) {
        wait_idle 1;
        select_console('root-console');
        my $test_machine = get_var("TEST_MACHINE");
        $self->reboot($test_machine, $reboot_timeout);
    }
    else {
        #leave root-ssh console
        set_var('SERIALDEV', '');
        $serialdev = 'ttyS1';
        bmwqemu::save_vars();
        console('root-ssh')->kill_ssh;
        console('sol')->disable;
        # do the activation manually - the sol can be anything normally
        select_console 'sol', await_console => 0;
        assert_screen("text-login", 600);
        type_string "root\n";
        assert_screen "password-prompt";
        type_password;
        send_key('ret');
        assert_screen "text-logged-in-root";

        #type reboot
        type_string("reboot\n");
        #switch to sut console
        reset_consoles;
        #wait boot finish and relogin
        login_console::login_to_console($self, $reboot_timeout);
    }
}

1;

