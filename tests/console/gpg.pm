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
#             wnereiz <wnereiz@member.fsf.org>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';

sub gpg_test {
    my ($key_size, $gpg_ver) = @_;

    my $name     = "SUSE Tester";
    my $username = $name . " " . $key_size;
    my $passwd   = "This_is_a_test_case";
    my $email    = "user\@suse.de";
    my $egg_file = 'egg';

    # GPG Key Generation

    # Generating key pair
    if ($gpg_ver ge 2.1) {
        # Preparing a config file for gpg --batch option
        assert_script_run(
            "echo \"\$(cat <<EOF
Key-Type: default
Key-Length: $key_size
Subkey-Type: default
Subkey-Length: $key_size
Name-Real: $username
Name-Email: $email
Expire-Date: 0
EOF
            )\" > $egg_file"
        );
        assert_script_run("cat $egg_file");

        script_run("gpg2 -vv --batch --full-generate-key $egg_file |& tee /dev/$serialdev", 0);
    }
    else {
        # Batch mode does not work in gpg version < 2.1. Workaround like using
        # expect does not work, so we use needles here.

        # Simple way to scroll screen to make sure command output always
        # appeared at the bottom for needles matching
        assert_script_run "gpg -h";

        script_run("gpg2 -vv --gen-key |& tee /dev/$serialdev", 0);
        assert_screen 'gpg-set-keytype';       # Your Selection?
        type_string "1\n";
        assert_screen 'gpg-set-keysize';       # What keysize do you want?
        type_string "$key_size\n";
        assert_screen 'gpg-set-expiration';    # Key is valid for? (0)
        send_key 'ret';
        assert_screen 'gpg-set-correct';       # Is this correct? (y/N)
        type_string "y\n";
        assert_screen 'gpg-set-realname';      # Real name:
        type_string "$username\n";
        assert_screen 'gpg-set-email';         # Email address:
        type_string "$email\n";
        assert_screen 'gpg-set-comment';       # Comment:
        send_key 'ret';
        assert_screen 'gpg-set-okay';          # Change (N)ame, (C)omment, (E)mail or (O)kay/(Q)uit?
        type_string "O\n";
    }

    assert_screen("gpg-passphrase-enter");
    type_string "REALSECRETPHRASE\n";          # Input insecure passphrase
    assert_screen("gpg-passphrase-insecure");
    send_key 'tab';
    send_key 'ret';
    assert_screen("gpg-passphrase-enter");
    type_string "$passwd\n";
    assert_screen("gpg-passphrase-reenter");
    type_string "$passwd\n";

    # According to FIPS PUB 186-4 Digital Signature Standard (DSS), only the
    # 2048 and 4096 key length should be supported. See bsc#1125740 comment#15
    # for details
    if (get_var('FIPS') || get_var('FIPS_ENABLED') && ($key_size == '1024' || $key_size == '4096')) {
        wait_serial("failed: Invalid value", 90) || die "It should failed with invalid value!";
        return;
    }

    wait_serial("gpg: key.*accepted as trusted key", 90) || die "Key generating failed!";

    assert_script_run("gpg --list-keys | grep '\\[ultimate\\] $username <$email>'");

    # Basic Functions

    my $tfile     = 'foo.txt';
    my $tfile_gpg = $tfile . '.gpg';
    my $tfile_asc = $tfile . '.asc';

    # Encryption and Decryption
    assert_script_run("echo 'foo test content' > $tfile");
    assert_script_run("gpg2 -r $email -e $tfile");
    assert_script_run("test -e $tfile_gpg");
    script_run("gpg2 -u $email -d $tfile_gpg |& tee /dev/$serialdev", 0);
    assert_screen("gpg-passphrase-unlock", 10);
    type_string "$passwd\n";
    wait_serial("foo test content", 90) || die "File decryption failed!";

    # Reload gpg-agent (if it is running) to disable the passphrase caching
    assert_script_run("pgrep gpg-agent && echo RELOADAGENT | gpg-connect-agent ; true");

    # Signing function
    script_run("gpg2 -u $email --clearsign $tfile |& tee /dev/$serialdev", 0);
    assert_screen("gpg-passphrase-unlock", 10);
    type_string "$passwd\n";
    assert_script_run("test -e $tfile_asc");
    assert_script_run("gpg2 -u $email --verify --verbose $tfile_asc");

    # Restore
    assert_script_run("rm -rf $tfile.* $egg_file");
    assert_script_run("rm -rf .gnupg && gpg -K");    # Regenerate default ~/.gnupg
}

sub run {
    select_console 'root-console';

    # increase entropy for key generation for s390x on svirt backend
    if (check_var('ARCH', 's390x') && (is_sle('>15') && (check_var('BACKEND', 'svirt')))) {
        zypper_call('in haveged');
        systemctl('start haveged');
    }

    # Obtain GnuPG version
    my $gpg_version_output = script_output("gpg --version");
    my ($gpg_version) = $gpg_version_output =~ /gpg \(GnuPG\) (\d\.\d)/;

    # GPG key generation and basic function testing with differnet key lengths
    # RSA keys may be between 1024 and 4096 only currently
    foreach my $len ('1024', '2048', '3072', '4096') {
        gpg_test($len, $gpg_version);
    }
}

1;
