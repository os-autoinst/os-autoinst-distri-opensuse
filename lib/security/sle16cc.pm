# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Helpers for the text mode screens of the SLE 16 Common Criteria system.
#   The installer and the booted system use their own needles (sle16-cc-*),
#   so the generic boot functions, like wait_boot, can not be used.
#   On s390x zKVM the installer and the booted system use the serial console
#   instead of the screen, the *_zkvm functions handle it.
# Maintainer: QE Security <none@suse.de>

package security::sle16cc;

use strict;
use warnings;
use base 'Exporter';
use testapi;
use utils qw(is_uefi_boot save_svirt_pty);

our @EXPORT = qw(
  fill_screen
  login_as_user
  unlock_and_login_cc_system
  type_line_zkvm
  answer_zkvm
  unlock_and_login_cc_system_zkvm
  permit_root_ssh_zkvm
);

use constant DEFAULT_TIMEOUT => 300;

# Messages of the CC installer (plain text mode) that stop the installation.
# The test fails at once instead of waiting for the timeout.
use constant INSTALLER_FAILURE =>
  qr/\nERROR:\n|=== (?:Loading the Configuration Failed|No Storage Actions|Installation Problem) ===/;

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

=head2 type_line_zkvm

    type_line_zkvm($text [, secret => 1]);

Send a line to the serial console of the s390x zKVM guest. The svirt console
must be selected and save_svirt_pty must be called before.

The text goes through the shell of the svirt host, so the text is quoted.
type_line_svirt does not quote the text, and passwords with special
characters break. Set secret to hide the text in the logs.

=cut

sub type_line_zkvm {
    my ($text, %args) = @_;
    (my $quoted = $text) =~ s/'/'\\''/g;
    enter_cmd "printf '%s\\n' '$quoted' > \$pty", secret => $args{secret} // 0;
}

=head2 answer_zkvm

    answer_zkvm($expect, $text [, timeout => $timeout] [, secret => 1]);

Wait for C<$expect> on the serial console and send C<$text> as a line. Die at
once if the CC installer shows an error.

=cut

sub answer_zkvm {
    my ($expect, $text, %args) = @_;
    my $output = wait_serial([$expect, INSTALLER_FAILURE], timeout => $args{timeout} // DEFAULT_TIMEOUT)
      or die "Not found on the serial console: $expect";
    die "The CC installer shows an error, see the serial console output" if $output =~ INSTALLER_FAILURE;
    type_line_zkvm($text, secret => $args{secret});
}

=head2 unlock_and_login_cc_system_zkvm

    unlock_and_login_cc_system_zkvm($user, $password);

Boot the installed system on s390x zKVM after a reboot. Enter the disk
encryption passphrase on the serial console and log in. The number of
passphrase prompts depends on the disk layout, so the function answers each
prompt until the login prompt is shown.

=cut

sub unlock_and_login_cc_system_zkvm {
    my ($user, $password) = @_;
    # The domain is defined again after the reboot, it has a new pty
    select_console 'svirt';
    save_svirt_pty;

    my $passphrase = qr/passphrase for/i;
    my $login = qr/login:/;
    my $max_prompts = 3;
    for my $prompt (1 .. $max_prompts + 1) {
        my $output = wait_serial([$passphrase, $login], timeout => DEFAULT_TIMEOUT)
          or die 'The disk encryption prompt or the login prompt is not shown';
        # The output can contain more than one prompt, the last one is valid
        my $last_passphrase = $output =~ /.*$passphrase/s ? $+[0] : -1;
        my $last_login = $output =~ /.*$login/s ? $+[0] : -1;
        last if $last_login > $last_passphrase;
        die "The login prompt is not shown after $max_prompts disk encryption prompts" if $prompt > $max_prompts;
        record_info('Unlock disk', "Entering the disk encryption passphrase ($prompt)");
        type_line_zkvm($password, secret => 1);
    }

    type_line_zkvm($user);
    answer_zkvm(qr/Password:/, $password, secret => 1);
    wait_serial(qr/\Q$user\E\@\S+:/, timeout => DEFAULT_TIMEOUT) or die "The user $user cannot log in";
}

=head2 permit_root_ssh_zkvm

    permit_root_ssh_zkvm($password);

On s390x zKVM all the root consoles of openQA, like root-console and
root-serial-ssh, use SSH. SLE 16 does not permit the root login with a password
over SSH, and the CC installer cannot change it like an Agama profile. Log out
the first user from the serial console, log in as root and permit the root
login over SSH.

=cut

sub permit_root_ssh_zkvm {
    my ($password) = @_;
    type_line_zkvm('exit');
    answer_zkvm(qr/login:/, 'root');
    answer_zkvm(qr/Password:/, $password, secret => 1);
    # The marker is calculated, so the echo of the command line does not match
    type_line_zkvm(q{echo 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/root.conf && systemctl restart sshd && echo "ROOT_SSH_$((40 + 2))"});
    wait_serial(qr/ROOT_SSH_42/, timeout => DEFAULT_TIMEOUT) or die 'Permitting the root login over SSH failed';
    type_line_zkvm('exit');
}

1;
