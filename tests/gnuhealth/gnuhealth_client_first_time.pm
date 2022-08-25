# SUSE's openQA tests
#
# Copyright 2017-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: first time startup for admin user for gnuhealth tryton
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'x11test';
use strict;
use warnings;
use testapi;
use version_utils 'is_leap';

sub run {
    my $gnuhealth = get_var('GNUHEALTH_CLIENT', 'gnuhealth-client');
    my $gnuhealth_34 = is_leap('<15.2');
    wait_screen_change { send_key 'tab' };
    send_key 'ret';
    assert_screen "$gnuhealth-login_password";
    enter_cmd "susetesting";
    assert_screen "$gnuhealth-module_configuration_wizard_start";
    send_key $gnuhealth_34 ? 'ret' : 'alt-o';
    # gnuhealth 4.0 introduced a new language configuration screen; gnuhealth 4.x exists since leap 15.4
    if (!is_leap('<15.4')) {
        assert_screen "$gnuhealth-configure-language";
        send_key 'alt-l';
        assert_screen "$gnuhealth-module_configuration_wizard-next_step";
        send_key 'alt-n';
    }
    assert_screen "$gnuhealth-module_configuration_wizard-add_users-welcome";
    send_key $gnuhealth_34 ? 'ret' : 'alt-o';
    assert_screen "$gnuhealth-module_configuration_wizard-add_users_dialog";
    # let's not add a user for now
    if ($gnuhealth_34) {
        send_key 'alt-e';
    }
    else {
        # newer versions have ambiguous hotkeys, need to select over two
        # different fields with "E" for hotkey. Let's hope the second button
        # is "End" and confirm it
        send_key 'alt-e';
        send_key 'alt-e';
        save_screenshot;
        send_key 'ret';
    }
    assert_screen "$gnuhealth-module_configuration_wizard-next_step";
    send_key 'alt-n';
    if ($gnuhealth_34) {
        assert_screen "$gnuhealth-module_configuration_wizard-configuration_done";
        send_key 'alt-o';
    }
    assert_screen "$gnuhealth-admin_view", 300;
}

sub test_flags {
    return {fatal => 1};
}

# overwrite the base class check for a clean desktop
sub post_run_hook {
}

1;
