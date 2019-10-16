# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: send an email using SMTP and receive it using IMAP
# Maintainer: Paolo Stivanin <pstivanin@suse.com>

package thunderbird_common;

use strict;
use warnings;
use base "x11test";
use testapi;
use utils;
use version_utils 'is_sle';

use base "Exporter";
use Exporter;

our @EXPORT = qw(tb_setup_account tb_send_message tb_check_email);

=head2 tb_setup_account

 tb_setup_account($proto, $account);

Create an email account in Thunderbird.
C<$proto> can be C<pop> or C<imap>.
C<$account> can be C<internal_account_A> or C<internal_account_B>.

=cut
sub tb_setup_account {
    my ($self, $proto, $account) = @_;

    my $config          = $self->getconfig_emailaccount;
    my $mail_box        = $config->{$account}->{mailbox};
    my $mail_sendServer = $config->{$account}->{sendServer};
    my $mail_recvServer = $config->{$account}->{recvServer};
    my $mail_user       = $config->{$account}->{user};
    my $mail_passwd     = $config->{$account}->{passwd};
    my $mail_sendport   = $config->{$account}->{sendport};
    my $port_key        = $proto eq 'pop' ? 'recvport' : 'imapport';
    my $mail_recvport   = $config->{$account}->{$port_key};

    send_key "alt-n";
    type_string "SUSE Test";
    send_key "alt-e";
    wait_screen_change { type_string "$mail_box" };
    send_key "alt-p";
    wait_screen_change { type_string "$mail_passwd" };

    send_key "alt-c";

    if ($proto eq 'pop') {
        assert_and_click 'thunderbird_wizard-imap-selected';
        assert_screen 'thunderbird_wizard-imap-pop-open';
        send_key 'down';
        send_key 'ret';
    }
    assert_screen "thunderbird_wizard-$proto-selected";

    assert_and_click 'thunderbird_startssl-selected-for-imap';
    assert_and_click 'thunderbird_security-select-none';
    assert_and_click 'thunderbird_startssl-selected-for-smtp';
    assert_and_click 'thunderbird_security-select-none';
    assert_and_click 'thunderbird_wizard-retest';
    assert_and_click 'thunderbird_wizard-done';
    assert_and_click 'thunderbird_I-understand-the-risks';
    assert_and_click 'thunderbird_risks-done';

    # skip additional integrations
    assert_and_click "thunderbird_skip-system-integration";

    assert_and_click "thunderbird_get-messages";
}

=head2 tb_send_message

 tb_send_message($account);

Test sending an email using Thunderbird.
C<$account> can be C<internal_account_A> or C<internal_account_B>.
Returns email subject.

=cut
sub tb_send_message {
    my ($self, $account) = @_;

    my $config       = $self->getconfig_emailaccount;
    my $mailbox      = $config->{$account}->{mailbox};
    my $mail_passwd  = $config->{$account}->{passwd};
    my $mail_subject = $self->get_dated_random_string(4);

    send_key "ctrl-m";
    assert_screen "thunderbird_mail-compose-message";
    wait_screen_change { type_string "$mailbox" };

    send_key "alt-s";
    wait_screen_change { type_string "$mail_subject this is a test mail" };

    send_key "tab";
    type_string "Test email send and receive.";
    send_key "ctrl-ret";
    # we can't use "ret" because it doesn't always work
    assert_and_click "thunderbird_really-send-message";

    assert_screen 'thunderbird_sent-folder-appeared';

    return $mail_subject;
}

=head2 tb_check_email

 tb_check_email($mail_search);

Check for new emails.
C<$mail_search> may be an email subject to search for.

=cut
sub tb_check_email {
    my ($self, $mail_search) = @_;

    wait_screen_change { send_key "shift-f5" };
    send_key "ctrl-shift-k";
    wait_screen_change { type_string "$mail_search" };
    assert_screen "thunderbird_sent-message-received";

    # delete the message
    assert_and_click "thunderbird_select-message";
    wait_still_screen 1;
    wait_screen_change { send_key "delete" };
    wait_still_screen 1;
    send_key "ctrl-shift-k";
    wait_screen_change { send_key "delete" };
}
