# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Helpers for the text mode screens of the SLE 16 Common Criteria system.
#   The installer and the booted system use their own needles (sle16-cc-*),
#   so the generic boot functions, like wait_boot, can not be used.
# Maintainer: QE Security <none@suse.de>

package security::sle16cc;

use strict;
use warnings;
use base 'Exporter';
use testapi;
use utils 'is_uefi_boot';

our @EXPORT = qw(fill_screen login_as_user unlock_and_login_cc_system);

use constant DEFAULT_TIMEOUT => 300;

=head2 fill_screen

    fill_screen($tag, $text);

Wait for a screen, type a text in the input field and confirm it.

=cut

sub fill_screen {
    my ($tag, $text) = @_;
    assert_screen $tag, DEFAULT_TIMEOUT;
    type_string $text;
    send_key 'ret';
}

=head2 login_as_user

    login_as_user($user, $password);

Log in on the text console of the booted system.

=cut

sub login_as_user {
    my ($user, $password) = @_;
    assert_screen 'sle16-cc-login-prompt', DEFAULT_TIMEOUT;
    type_string $user;
    send_key 'ret';
    assert_screen 'sle16-cc-password-prompt';
    type_string $password;
    send_key 'ret';
}

=head2 unlock_and_login_cc_system

    unlock_and_login_cc_system($user, $password);

Boot the installed system after a reboot. Enter the disk encryption passphrase,
select the default grub entry if the menu is shown and log in on the text
console. The prompt looks different on UEFI, where tianocore shows it.

=cut

sub unlock_and_login_cc_system {
    my ($user, $password) = @_;
    if (is_uefi_boot()) {
        record_info('UEFI boot', 'Using the tianocore disk encryption prompt');
        fill_screen 'sle16-cc-disk-encryption-prompt-tianocore', $password;
    }
    else {
        record_info('BIOS boot', 'Using the BIOS disk encryption prompt');
        fill_screen 'sle16-cc-disk-encryption-prompt', $password;
    }
    # The installed system may boot without showing the grub menu. Wait for the
    # menu or for the login prompt, and select the default entry only if the
    # menu is shown.
    assert_screen [qw(sle16-cc-grub-menu-installed sle16-cc-login-prompt)], DEFAULT_TIMEOUT;
    if (match_has_tag 'sle16-cc-grub-menu-installed') {
        record_info('Grub menu', 'The grub menu is shown, selecting the default entry');
        send_key 'ret';
    }
    else {
        record_info('No grub menu', 'The system boots without showing the grub menu');
    }
    login_as_user($user, $password);
    wait_still_screen 2;
}

1;
