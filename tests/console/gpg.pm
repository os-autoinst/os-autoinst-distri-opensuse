# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: gpg key generation and passphrase test
# Maintainer: Petr Cervinka <pcervinka@suse.com>

use base "consoletest";
use strict;
use testapi;

sub run {
    select_console 'user-console';

    # Get gpg version and base on the result choose different test
    my $gpg_version_output = script_output("gpg --version");
    my ($gpg_version) = $gpg_version_output =~ /gpg \(GnuPG\) (\d\.\d)/;
    # generate gpg key
    if ($gpg_version eq "2.0") {
        # gpg version 2.0.x
        type_string "gpg2 --gen-key\n";
    }
    else {
        # gpg version >= 2.1.x
        type_string "gpg2 --full-generate-key\n";
    }
    wait_still_screen 1;
    type_string "1\n";
    wait_still_screen 1;
    type_string "2048\n";
    wait_still_screen 1;
    type_string "0\n";
    wait_still_screen 1;
    type_string "y\n";
    wait_still_screen 1;
    type_string "Test User\n";
    wait_still_screen 1;
    type_string "user\@example.com\n", 1;
    type_string "\n";
    wait_still_screen 1;
    save_screenshot;
    type_string "O\n";

    assert_screen("gpg-enter-passphrase");
    # enter wrong passphrase
    type_string "REALSECRETPHRASE\n";
    assert_screen("gpg-incorrect-passphrase");
    type_string "\t\n", 1;
    # enter correct passphrase
    type_string "R34LS3CR3TPHR4S3\n";
    wait_still_screen 1;
    type_string "R34LS3CR3TPHR4S3\n";
    wait_still_screen 1;
    # list gpg keys
    validate_script_output("gpg --list-keys", sub { m/\[ultimate\] Test User <user\@example\.com>/ });
}

1;
# vim: set sw=4 et:
