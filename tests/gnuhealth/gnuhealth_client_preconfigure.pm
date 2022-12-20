# SUSE's openQA tests
#
# Copyright 2017-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: first time administration and setup work for gnuhealth client
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'x11test';
use strict;
use warnings;
use testapi;
use version_utils 'is_leap';

sub run {
    my $gnuhealth = get_var('GNUHEALTH_CLIENT', 'gnuhealth-client');
    x11_start_program($gnuhealth);
    assert_and_click "$gnuhealth-manage_profiles";
    # wait for indexing to be done
    wait_still_screen(5);
    assert_and_click "$gnuhealth-manage_profiles-add";
    wait_still_screen(3);
    type_string 'localhost';
    send_key_until_needlematch "$gnuhealth-manage_profiles-host_textfield_selected", 'tab';
    wait_still_screen(3);
    type_string 'localhost';
    send_key 'tab';
    assert_screen "$gnuhealth-manage_profiles-database_selected";
    type_string 'admin';
    # back to profiles menu
    assert_screen "$gnuhealth-manage_profiles-add", 300;
    send_key 'ret';
    # back to login dialog
    assert_screen "$gnuhealth-startup";
}

sub test_flags {
    return {fatal => 1};
}

# overwrite the base class check for a clean desktop
sub post_run_hook {
}

1;
