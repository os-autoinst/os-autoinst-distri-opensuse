# SUSE's openQA tests
#
# Copyright © 2017-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: gpg key generation, passphrase test, encrypt file and support fips test
# Maintainer: Petr Cervinka <pcervinka@suse.com>, Dehai Kong <dhkong@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';

my $username = $testapi::username;
my $passwd   = $testapi::password;
my $email    = "user\@example.com";

sub gpg_generate_key {
    my ($key_size) = @_;
    my $user_name = $username . " " . $key_size;

    # Get gpg version and base on the result choose different test
    my $gpg_version_output = script_output("gpg --version");

    my ($gpg_version) = $gpg_version_output =~ /gpg \(GnuPG\) (\d\.\d)/;
    my $genkey_opt = ($gpg_version ge 2.1) ? '--full-generate-key' : '--gen-key';

    # generate gpg key
    script_run "gpg2 -vv $genkey_opt |& tee /dev/$serialdev";

    wait_still_screen 1;
    type_string "1\n";
    wait_still_screen 1;
    type_string "$key_size\n";
    wait_still_screen 1;
    type_string "0\n";
    wait_still_screen 1;
    type_string "y\n";
    wait_still_screen 1;
    type_string "$user_name\n";
    wait_still_screen 1;
    type_string "$email\n", 1;
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
    type_string "$passwd\n";
    wait_still_screen 1;
    type_string "$passwd\n";
    wait_still_screen 1;
    if (get_var("FIPS") || get_var("FIPS_ENABLED") && $key_size == 1024) {
        wait_serial("gpg: agent_genkey failed: Invalid value", 120) || die "It should failed with invalid value!";
    }
    else {
        # list gpg keys
        assert_script_run("gpg --list-keys | grep '\\[ultimate\\] $user_name <$email>'");
    }
}

sub gpg_encrypt_file {
    my ($key_size) = @_;
    my $user_name  = $username . " " . $key_size;
    my $user_id    = $user_name . " " . "\<$email\>";

    # prepare a text file
    assert_script_run("touch gtest.txt");

    # Should generate encrypted file gtest.txt.gpg
    assert_script_run("gpg2 -r \"$user_id\" -e gtest.txt");

    # check encrypted file gtest.txt.gpg
    assert_script_run("ls | grep gtest.txt.gpg");

    # Decrypt function can be work
    script_run("gpg2 -u \"$user_id\" -d gtest.txt.gpg", 0);
    wait_still_screen 1;
    type_string "$passwd\n";
    wait_still_screen 1;

    # Should generate signature file gtest.txt.asc
    script_run("gpg2 -u \"$user_id\" --clearsign gtest.txt", 0);
    wait_still_screen 1;
    type_string "$passwd\n";
    wait_still_screen 1;
    assert_script_run("ls | grep gtest.txt.asc");

    # Verify the signature
    assert_script_run("gpg2 -u \"$user_id\" --verify gtest.txt.asc");

    # clean up
    assert_script_run("ls | grep gtest | xargs -i rm -f {}");
}

sub run {
    select_console 'root-console';
    # increase entropy for key generation for s390x on svirt backend
    if (check_var('ARCH', 's390x') && (is_sle('>15') && (check_var('BACKEND', 'svirt')))) {
        zypper_call('in haveged');
        systemctl('start haveged');
    }

    # gpg key generated and file encrypted with two size of key
    for my $key_size (2048, 3072) {
        gpg_generate_key($key_size);
        gpg_encrypt_file($key_size);
    }

    # fips environment, 1024 bit RSA size key should NOT work
    if (get_var("FIPS") || get_var("FIPS_ENABLED")) {
        gpg_generate_key(1024);
    }
}

1;
