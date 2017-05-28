# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: first time startup for admin user for gnuhealth tryton
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'x11test';
use strict;
use testapi;

sub run() {
    send_key_until_needlematch 'tryton-login_password', 'tab';
    type_string "susetesting\n";
    assert_screen 'tryton-module_configuration_wizard_start';
    send_key 'ret';
    assert_screen 'tryton-module_configuration_wizard-add_users-welcome';
    send_key 'ret';
    assert_screen 'tryton-module_configuration_wizard-add_users_dialog';
    # let's not add a user for now
    wait_screen_change { send_key 'alt-o' };
    wait_screen_change { send_key 'alt-e' };
    wait_screen_change { send_key 'alt-n' };
    send_key 'alt-o';
    assert_screen 'tryton-admin_view', 300;
}

sub test_flags() {
    return {fatal => 1};
}

# overwrite the base class check for a clean desktop
sub post_run_hook {
}

1;
# vim: set sw=4 et:
