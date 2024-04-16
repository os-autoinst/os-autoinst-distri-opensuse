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
use version_utils 'is_sle';
use registration qw(add_suseconnect_product get_addon_fullname);

sub prepare_repositories {
    # add workstation extension
    my $OS_VERSION = script_output("grep VERSION_ID /etc/os-release | cut -c13- | head -c -2");
    my $ARCH = get_required_var('ARCH');
    # on 15-SP{4,5}-QR the auto agree with licenses command is not there
    my $EXTRA_CMD = (is_sle('<15-SP6') && (check_var('FLAVOR', 'Online-QR') || check_var('FLAVOR', 'Full-QR'))) ? "" : "--auto-agree-with-licenses";
    assert_script_run("SUSEConnect -p sle-we/$OS_VERSION/$ARCH $EXTRA_CMD --gpg-auto-import-keys -r " . get_var('SCC_REGCODE_WE'), timeout => 300);

    # disable nvidia repository to avoid the 'doesn't contain public key data' error
    zypper_call(q{mr -d $(zypper lr | awk -F '|' '{IGNORECASE=1} /nvidia/ {print $2}')}, exitcode => [0, 3]);
}

sub run {
    select_console 'root-console';

    prepare_repositories if is_sle();

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
    if (check_screen("seahorse-sshkey-inhibit", timeout => 8)) {
        assert_and_click "seahorse-sshkey-inhibit";
    }
    assert_screen 'seahorse-sshkey-passphrase';    # sshkey passphrase
    type_password;
    send_key 'ret';
    if (check_screen("seahorse-sshkey-inhibit", timeout => 8)) {
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
