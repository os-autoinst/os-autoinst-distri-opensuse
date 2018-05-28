# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: first time administration and setup work for gnuhealth-client
# Maintainer: Christopher Hofmann <cwh@suse.de>

use base 'x11test';
use strict;
use testapi;
use version_utils qw(is_leap is_tumbleweed);

sub run {
    x11_start_program('gnuhealth-client');
    assert_and_click 'gnuhealth-client-manage_profiles';
    # wait for indexing to be done
    wait_still_screen(3);
    assert_and_click 'gnuhealth-client-manage_profiles-add';
    type_string 'localhost';
    send_key_until_needlematch 'gnuhealth-client-manage_profiles-host_textfield_selected', 'tab';
    type_string 'localhost';
    send_key 'tab';
    if (is_tumbleweed || is_leap('42.3+')) {
        assert_screen 'gnuhealth-client-manage_profiles-database_selected';
        type_string 'admin';
    }
    else {
        # button 'create' should appear, weird GUI behaviour
        assert_and_click 'gnuhealth-client-manage_profiles-create_database';
        # gnuhealth server password
        type_string 'susetesting';
        send_key 'tab';
        # database name
        type_string 'gnuhealth_demo';
        send_key 'tab';
        send_key 'tab';
        # admin password
        type_string 'susetesting';
        send_key 'tab';
        type_string 'susetesting';
        # wait for create button to be active
        assert_and_click 'gnuhealth-client-manage_profiles-create_database-create';

    }
    # back to profiles menue
    assert_screen 'gnuhealth-client-manage_profiles-add', 300;
    send_key 'ret';
    # back to login dialog
    assert_screen 'gnuhealth-client';
}

sub test_flags {
    return {fatal => 1};
}

# overwrite the base class check for a clean desktop
sub post_run_hook {
}

1;
