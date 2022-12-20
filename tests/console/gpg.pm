# SUSE's openQA tests
#
# Copyright 2017-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: gpg2 haveged
# Summary: gpg key generation, passphrase test, encrypt file and support fips test
# - Install haveged if necessary
# - Generate gpg key pair using pre determined data (using gpg itself or openqa
#   commands, depending on gpg version)
# - Check if key length is between 2048 and 4096 bits
# - Encrypt text file
# - Decrypt gpg file created
# - Reload gpg-agent (drop passphrase cache)
# - Sign test file
# - Check test file signature
# - Cleanup
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#65375, poo#97685, poo#104556

use base "consoletest";
use strict;
use warnings;
use testapi;
use Utils::Backends;
use Utils::Architectures;
use utils;
use version_utils 'is_sle';
use utils qw(zypper_call package_upgrade_check);

sub gpg_test {
    my ($key_size, $gpg_ver) = @_;

    my $name = "SUSE Tester";
    my $username = $name . " " . $key_size;
    my $passwd = "This_is_a_test_case";
    my $email = "user\@suse.de";
    my $egg_file = 'egg';

    # GPG Key Generation

    # Generating key pair
    if ($gpg_ver ge 2.1) {
        # Preparing a config file for gpg --batch option
        assert_script_run(
            "echo \"\$(cat <<EOF
Key-Type: RSA
Key-Length: $key_size
Subkey-Type: RSA
Subkey-Length: $key_size
Name-Real: $username
Name-Email: $email
Expire-Date: 0
EOF
            )\" > $egg_file"
        );
        assert_script_run("cat $egg_file");

        # Kill gpg-agent service when executing gpg2 command in case gpg-agent
        # does NOT see current environment variable: LIBGCRYPT_FORCE_FIPS_MODE=1
        # when gpg version > 2.1
        # Refer to bug #1198135
        if (get_var('FIPS_ENV_MODE')) {
            assert_script_run('gpgconf --kill gpg-agent');
        }

        script_run("gpg2 -vv --batch --full-generate-key $egg_file &> /dev/$serialdev; echo gpg-finished-\$? >/dev/$serialdev", 0);
    }
    else {
        # Batch mode does not work in gpg version < 2.1. Workaround like using
        # expect does not work, so we use needles here.

        # Simple way to scroll screen to make sure command output always
        # appeared at the bottom for needles matching
        assert_script_run "gpg -h";

        script_run("gpg2 -vv --gen-key &> /dev/$serialdev; echo gpg-finished-\$? >/dev/$serialdev", 0);
        assert_screen 'gpg-set-keytype';    # Your Selection?
        enter_cmd "1";
        assert_screen 'gpg-set-keysize';    # What keysize do you want?
        enter_cmd "$key_size";
        assert_screen 'gpg-set-expiration';    # Key is valid for? (0)
        send_key 'ret';
        assert_screen 'gpg-set-correct';    # Is this correct? (y/N)
        enter_cmd "y";
        assert_screen 'gpg-set-realname';    # Real name:
        enter_cmd "$username";
        assert_screen 'gpg-set-email';    # Email address:
        enter_cmd "$email";
        assert_screen 'gpg-set-comment';    # Comment:
        send_key 'ret';
        assert_screen 'gpg-set-okay';    # Change (N)ame, (C)omment, (E)mail or (O)kay/(Q)uit?
        enter_cmd "O";
    }

    assert_screen("gpg-passphrase-enter");
    enter_cmd "REALSECRETPHRASE";    # Input insecure passphrase
    assert_screen("gpg-passphrase-insecure");
    send_key 'tab';
    send_key 'ret';
    assert_screen("gpg-passphrase-enter");
    enter_cmd "$passwd";
    assert_screen("gpg-passphrase-reenter");
    enter_cmd "$passwd";

    # According to FIPS PUB 186-4 Digital Signature Standard (DSS), only the
    # 2048 and 3072 key length should be supported by default.
    #
    # In SPEC, The Digital Signature Standard, section B 3.3 states:
    # If nlen is neither 2048 nor 3072, then return (FAILURE, 0, 0).
    # Only 2048 and 3072 are the allowed modulus (n) lengths when generating
    # the random probable primes p and q for RSA.
    #
    # Please see bsc#1165902#c40 that RSA 4096 can be accepted even in FIPS mode
    if (get_var('FIPS') || get_var('FIPS_ENABLED') && ($key_size == '1024')) {
        wait_serial("failed: Invalid value", 90) || die "It should failed with invalid value!";
        return;
    }

    wait_serial("gpg-finished-0", 90) || die "Key generation failed!";

    assert_script_run("gpg --list-keys | grep '\\[ultimate\\] $username <$email>'");

    # Basic Functions

    my $tfile = 'foo.txt';
    my $tfile_gpg = $tfile . '.gpg';
    my $tfile_asc = $tfile . '.asc';

    # Encryption and Decryption
    assert_script_run("echo 'foo test content' > $tfile");
    assert_script_run("gpg2 -r $email -e $tfile");
    assert_script_run("test -e $tfile_gpg");
    script_run("gpg2 -u $email -d $tfile_gpg &> /dev/$serialdev", 0);
    assert_screen("gpg-passphrase-unlock", 10);
    enter_cmd "$passwd";
    wait_serial("foo test content", 90) || die "File decryption failed!";

    # Reload gpg-agent (if it is running) to disable the passphrase caching
    assert_script_run("pgrep gpg-agent && echo RELOADAGENT | gpg-connect-agent ; true");

    # Signing function
    script_run("gpg2 -u $email --clearsign $tfile &> /dev/$serialdev", 0);
    assert_screen("gpg-passphrase-unlock", 10);
    enter_cmd "$passwd";
    assert_script_run("test -e $tfile_asc");
    assert_script_run("gpg2 -u $email --verify --verbose $tfile_asc");

    # Restore
    assert_script_run("rm -rf $tfile.* $egg_file");
    assert_script_run("rm -rf .gnupg && gpg -K");    # Regenerate default ~/.gnupg
}

sub run {
    select_console 'root-console';

    # increase entropy for key generation for s390x on svirt backend
    if (is_s390x && (is_sle('15+') && (is_svirt))) {
        zypper_call('in haveged');
        systemctl('start haveged');
    }

    # Obtain GnuPG version
    my $gpg_version_output = script_output("gpg --version");
    my ($gpg_version) = $gpg_version_output =~ /gpg \(GnuPG\) (\S+)/;
    record_info('gpg version', "Version of Current gpg package: $gpg_version");

    # Libgcrypt and libgcrypt20-hmac version check
    # Refer to poo#107509
    my $pkg_list = {
        libgcrypt20 => '1.9.0',
        'libgcrypt20-hmac' => '1.9.0'
    };
    zypper_call("in " . join(' ', keys %$pkg_list));

    if (is_sle('>=15-sp4')) {
        package_upgrade_check($pkg_list);
    }
    else {
        foreach my $pkg_name (keys %$pkg_list) {
            my $pkg_ver = script_output("rpm -q --qf '%{version}\n' $pkg_name");
            record_info("$pkg_name version", "Version of Current package: $pkg_ver");
        }
    }

    # GPG key generation and basic function testing with different key lengths
    # RSA keys may be between 1024 and 4096 only currently
    foreach my $len ('1024', '2048', '3072', '4096') {
        gpg_test($len, $gpg_version);
    }
}

1;
