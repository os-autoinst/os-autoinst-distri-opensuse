# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test seahorse (GNOME Keyring frontend)
#    * As a side effect, it initializes the keyring so that other
#      tests running later can access an existing keyring (e.g. chromium &
#      chrome). This allows us not having to handle special cases there for
#      creating new keyring databases (Which, potentially, every application
#      could be asking for).
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "x11test";
use strict;
use testapi;

sub run {
    x11_start_program('seahorse');
    send_key "ctrl-n";                                # New keyring
    assert_screen "seahorse-keyring-selector";        # Dialog "Select type to create"
    assert_and_dclick "seahorse-password-keyring";    # Selection: Password keyring
    my @tags = qw(seahorse-name-new-keyring ok_on_top);
    assert_screen \@tags;                             # "Add a password keyring; name it"
                                                      # may be with ok buttom on top or bottom of popup
    if (match_has_tag "ok_on_top") {
        record_info 'alt-o ignored', 'poo#42686 so try ret key';
        type_string "Default Keyring";                # Name of the keyring
        send_key "ret";                               # &Ok
    }
    else {
        type_string "Default Keyring";                # Name of the keyring
        send_key "alt-o";                             # &Ok
    }
    assert_screen "seahorse-password-dialog";         # Dialog "Passphrase for the new keyring"
    type_password;                                    # Users password (for auto unlock, it has to be the same)
    send_key "ret";                                   # Next field (confirm PW)
    type_password;                                    # Re-type user password
    send_key "ret";                                   # Confirm password
    assert_and_click "seahorse-default_keyring", 'right';      # right click the new keyring
    assert_and_click "seahorse-set_as_default", 'left', 60;    # Set the new keyring as default
    send_key "alt-f4";                                         # Close seahorse
}

sub test_flags {
    # milestone as we initialize a keyring, which future tests might rely on
    # without milestone, this step might be undone on snapshot revert
    return {milestone => 1};
}

1;
