# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: first time startup for admin user for gnuhealth tryton
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'x11test';
use strict;
use warnings;
use testapi;
use version_utils qw(is_leap is_tumbleweed);

sub run {
    my $gnuhealth = get_var('GNUHEALTH_CLIENT', 'gnuhealth-client');
    if (is_tumbleweed || is_leap('42.3+')) {
        wait_screen_change { send_key 'tab' };
        send_key 'ret';
        assert_screen "$gnuhealth-login_password";
    }
    else {
        send_key_until_needlematch "gnuhealth-login_password", 'tab';
    }
    type_string "susetesting\n";
    assert_screen "$gnuhealth-module_configuration_wizard_start";
    send_key 'ret';
    assert_screen "$gnuhealth-module_configuration_wizard-add_users-welcome";
    send_key 'ret';
    assert_screen "$gnuhealth-module_configuration_wizard-add_users_dialog";
    # let's not add a user for now
    send_key 'alt-e';
    assert_screen "$gnuhealth-module_configuration_wizard-next_step";
    send_key 'alt-n';
    assert_screen "$gnuhealth-module_configuration_wizard-configuration_done";
    send_key 'alt-o';
    assert_screen "$gnuhealth-admin_view", 300;
}

sub test_flags {
    return {fatal => 1};
}

# overwrite the base class check for a clean desktop
sub post_run_hook {
}

1;
