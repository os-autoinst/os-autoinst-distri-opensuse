# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Test all encrypt ciphers of ecryptfs
# Maintainer: Starry Wang <starry.wang@suse.com> Ben Chou <bchou@suse.com>
# Tags: poo#110355

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use Utils::Architectures;

sub ecryptfs_mount {
    my ($cipher) = @_;
    my $passwd = 'testpasswd';

    assert_script_run('mkdir .private private');
    my $script = "mount -t ecryptfs -o key=passphrase:passphrase_passwd=$passwd ./.private ./private | tee /dev/$serialdev";
    enter_cmd($script);
    # Select cipher
    enter_cmd($cipher);
    # Select key bytes, disable plaintext passthrough, disable filename encryption
    for (1 .. 3) {
        send_key('ret');
    }
    # Would you like to proceed with the mount
    enter_cmd('yes');
    # Would you like to avoid this warning in the future
    enter_cmd('no');

    # The mount failed should be expected in fips kernel mode
    if (get_var('FIPS_ENABLED') && !get_var('FIPS_ENV_MODE')) {
        wait_serial('Operation not permitted', 10) || die 'eCryptfs test failed in FIPS mode';
        record_info('FIPS kernel mode', "the mount failed is expected in fips kernel mode");
        assert_script_run 'rm -r .private private';
        return;
    }

    # Check the result of mount command
    wait_serial('Mounted eCryptfs', 10) || die 'eCryptfs mount failed';
    validate_script_output('mount | grep -m 1 ecryptfs', sub { m/\/root\/private/ });
    # The testfile should be readable and writable
    assert_script_run('cd private && touch testfile && echo Hello > testfile && grep Hello testfile && cd ..');
    # Check that testfile is a binary. This fails if file is plain-text (therefore decrypted)
    assert_script_run("perl -E 'exit((-B \$ARGV[0])?0:1);' .private/testfile");

    assert_script_run('umount -l private');
    validate_script_output('ls -1 private/ | wc -l', sub { m/0/ });

    # Clean up
    assert_script_run('rm -r .private private');
    record_info("$cipher", "ecrypt: cipher $cipher passed");
}

sub run {
    my ($self) = @_;

    select_console('root-console');

    zypper_call('in ecryptfs-utils');
    assert_script_run('modprobe ecryptfs');
    foreach my $cipher ('aes', 'blowfish', 'des3_ede', 'twofish', 'cast6', 'cast5') {
        ecryptfs_mount($cipher);
    }
}

1;
