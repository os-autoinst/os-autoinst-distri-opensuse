# SUSE's gnome-keyring tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: seahorse
# Summary: Test add new secure shell key with gnome-keyring
# Maintainer: Zhaocong Jia <zcjia@suse.com> Grace Wang <grace.wang@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';

sub run {
    select_console 'root-console';
    zypper_call "in seahorse";
    select_console 'x11';

    x11_start_program('seahorse');
    send_key "ctrl-n";    # New Keyring
    assert_screen 'seahorse-keyring-selector';    # Dialog "Select type to create"
    send_key_until_needlematch("seahorse-secure-shell-key", "down");    # Selected secure shell key
    send_key 'ret';
    assert_screen 'seahorse-new-sshkey';    # Dialog : "Add password; New ssh key"
    send_key 'alt-d';
    type_string "Keyring test";    # Name of new ssh key
    send_key 'alt-j';    # Just Create ssh key without setup
    if (check_screen("seahorse-sshkey-inhibit", timeout => 3)) {
        assert_and_click "seahorse-sshkey-inhibit";
    }
    assert_screen 'seahorse-sshkey-passphrase';    # sshkey passphrase
    type_password;
    send_key 'ret';
    if (check_screen("seahorse-sshkey-inhibit", timeout => 3)) {
        assert_and_click "seahorse-sshkey-inhibit";
    }
    assert_screen 'seahorse-sshkey-passphrase-retype';    # sshkey passphrase retype
    type_password;
    send_key 'ret';
    assert_and_click "seahorse-sshkey-list";    # check the sshkey list
    assert_screen "seahorse-display-sshkey";    # verify the new ssh key has been added to the keyring
    send_key "alt-f4";    # close seahorse
}

1;
