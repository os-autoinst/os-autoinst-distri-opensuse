# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: New test: Seahorse
#    Serves two purposes:
#    * Tests seahorse (GNOME Keyring frontend)
#    * As a side effect, it initializes the keyring so that other
#      tests running later can access an existing keyring (e.g. chromium &
#      chrome). This allows us not having to handle special cases there for
#      creating new keyring databases (Which, potentially, every application
#      could be asking for).
# G-Maintainer: Dominique Leuenberger <dimstar@opensuse.org>

use base "x11test";
use strict;
use testapi;

sub run() {
    my $self = shift;
    x11_start_program("seahorse");
    assert_screen 'seahorse-launched', 15;    # Seahorse main window appeared
    send_key "ctrl-n";                                # New keyring
    assert_screen "seahorse-keyring-selector";        # Dialog "Select type to create"
    assert_and_dclick "seahorse-password-keyring";    # Selection: Password keyring
    assert_screen "seahorse-name-new-keyring";        # Dialog  "Add a password keyring; name it"
    type_string "Default Keyring";                    # Name of the keyring
    send_key "alt-o";                                 # &Ok
    assert_screen "seahorse-password-dialog";         # Dialog "Passphrase for the new keyring"
    type_password;                                    # Users password (for auto unlock, it has to be the same)
    send_key "ret";                                   # Next field (confirm PW)
    type_password;                                    # Re-type user password
    send_key "ret";                                   # Confirm password
    assert_and_click "seahorse-default_keyring", 'right';    # right click the new keyring
    assert_and_click "seahorse-set_as_default";              # Set the new keyring as default
    send_key "alt-f4";                                       # Close seahorse
}

sub test_flags() {
    # milestone as we initialize a keyring, which future tests might rely on
    # without milestone, this step might be undone on snapshot revert
    return {milestone => 1};
}

1;
# vim: set sw=4 et:
