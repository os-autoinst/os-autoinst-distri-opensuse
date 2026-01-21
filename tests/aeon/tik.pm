# Copyright 2014-2026 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

use Mojo::Base 'basetest';
use testapi;

sub run {
    # Use the common password as passphrase
    my $encryption_passphrase = $testapi::password;

    # wait for welcome screen to appear, this can take a while
    assert_screen 'tik-welcome', 600;

    # click the welcome screen, to close the GNOME Overview
    assert_and_click 'tik-welcome';

    # press "Install Now"
    send_key 'ret';

    # ignore warning about tpm
    assert_screen 'tik-warning-no-tpm';
    send_key 'ret';

    # confirm disk erasure
    assert_and_click 'tik-confirm-erase-disk';

    # deploy
    assert_screen 'tik-deploying-image';

    # give the deployment some time, wait for the encryption info screen
    assert_screen 'tik-set-encryption-passphrase-1', 600;
    send_key 'ret';

    # input a passphrase
    assert_screen 'tik-set-encryption-passphrase-2';
    type_string $encryption_passphrase;
    send_key 'ret';
    wait_still_screen 3;

    # repeat the passphrase
    type_string $encryption_passphrase;
    send_key 'ret';

    # confirm the encryption recovery key
    assert_screen 'tik-encryption-recovery-key';
    send_key 'ret';

    # confirm reboot
    assert_screen 'tik-installation-complete';
    send_key 'ret';
}

1;
