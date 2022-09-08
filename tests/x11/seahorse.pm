# SUSE's openQA tests
#
# Copyright 2016-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: seahorse
# Summary: Test seahorse (GNOME Keyring frontend)
#    * As a side effect, it initializes the keyring so that other
#      tests running later can access an existing keyring (e.g. chromium &
#      chrome). This allows us not having to handle special cases there for
#      creating new keyring databases (Which, potentially, every application
#      could be asking for).
# Maintainer: QE Core <qe-core@suse.de>

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {
    x11_start_program('seahorse');
    send_key "ctrl-n";    # New keyring
    assert_screen "seahorse-keyring-selector";    # Dialog "Select type to create"
    wait_still_screen(3);
    assert_and_dclick "seahorse-password-keyring";    # Selection: Password keyring
    my @tags = qw(seahorse-name-new-keyring ok_on_top);
    assert_screen \@tags, 60;    # "Add a password keyring; name it"
                                 # may be with ok buttom on top or bottom of popup
    if (match_has_tag "ok_on_top") {
        record_info 'alt-o ignored', 'poo#42686 so try ret key';
        type_string "Default Keyring";    # Name of the keyring
        wait_still_screen(1, 2);
        send_key "ret";    # &Ok
    }
    else {
        type_string "Default Keyring";    # Name of the keyring
        wait_still_screen(1, 2);
        send_key "alt-o";    # &Ok
    }
    assert_screen "seahorse-password-dialog";    # Dialog "Passphrase for the new keyring"
    type_password;    # Users password (for auto unlock, it has to be the same)
    send_key "ret";    # Next field (confirm PW)
    type_password;    # Re-type user password
    send_key "ret";    # Confirm password
    wait_still_screen 1;
    if (check_screen "seahorse-keyring-locked") {
        assert_and_click "unlock";
        type_password;
        send_key "ret";
    }
    assert_screen [qw(seahorse-collecton-is-empty seahorse-default_keyring)];
    if (match_has_tag "seahorse-collecton-is-empty") {
        record_soft_failure 'Missing entries of Passwords, Keys, Certificates, see boo#1175513';
        send_key_until_needlematch("generic-desktop", "alt-f4", 6, 5);
    }
    elsif (match_has_tag "seahorse-default_keyring") {
        assert_and_click('seahorse-default_keyring', button => 'right');    # right click the new keyring
        assert_and_click('seahorse-set_as_default', timeout => 60);    # Set the new keyring as default
        send_key "alt-f4";    # Close seahorse
    }
}

sub test_flags {
    # milestone as we initialize a keyring, which future tests might rely on
    # without milestone, this step might be undone on snapshot revert
    return {milestone => 1};
}

1;
