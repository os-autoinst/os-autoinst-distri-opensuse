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
use ipmi_backend_utils;
use base "proxymode";

sub reboot_and_wait_up {
    my $self           = shift;
    my $reboot_timeout = shift;

    if (get_var("PROXY_MODE")) {
        select_console('root-console');
        my $test_machine = get_var("TEST_MACHINE");
        $self->reboot($test_machine, $reboot_timeout);
    }
    else {
        # leave ssh console and switch to sol console
        # Now we support resetting ipmi main board during test via
        # a testsuite setting switch MC_RESET_BEFORE_REBOOT.
        # Reboot is a weak point which suffers ipmi sol unstability
        # So do ipmi mc reset before reboot can increase stability
        my $mc_reset_flag = 'off';
        if (check_var('MC_RESET_BEFORE_REBOOT', 1)) {
            $mc_reset_flag = 'on';
        }
        switch_from_ssh_to_sol_console(mc_reset_flag => $mc_reset_flag);
        #login
        #The timeout can't be too small since autoyast installation
        #need to wait 2nd phase install to finish
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

