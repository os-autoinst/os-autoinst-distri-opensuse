# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: send an email using SMTP and receive it using IMAP
#          added multimachine server using SSL.
# Maintainer: Paolo Stivanin <pstivanin@suse.com>
#       Multimachine: Marcelo Martins <mmartins@suse.com>

package thunderbird_common;

use strict;
use warnings;
use base "x11test";
use testapi;
use utils;
use version_utils qw(is_sle is_tumbleweed);

use base "Exporter";
use Exporter;

our @EXPORT = qw(tb_setup_account tb_send_message tb_check_email);

=head2 tb_setup_account
 tb_setup_account($proto, $account);
Create an email account in Thunderbird.
C<$proto> can be C<pop> or C<imap>.
C<$account> can be C<internal_account_A> or C<internal_account_B> or C<internal_account_C> or C<internal_account_D>.
=cut

sub tb_setup_account {
    my $hostname = get_var('HOSTNAME') // '';
    my ($self, $proto, $account) = @_;

    my $config = $self->getconfig_emailaccount;
    my $mail_box = $config->{$account}->{mailbox};
    my $mail_sendServer = $config->{$account}->{sendServer};
    my $mail_recvServer = $config->{$account}->{recvServer};
    my $mail_user = $config->{$account}->{user};
    my $mail_passwd = $config->{$account}->{passwd};
    my $mail_sendport = $config->{$account}->{sendport};
    my $port_key = $proto eq 'pop' ? 'recvport' : 'imapport';
    my $mail_recvport = $config->{$account}->{$port_key};
    my $new_gui = 0;

    if (check_screen 'thunderbird-new-gui') {
        $new_gui = 1;
        wait_still_screen(2, 4);
        type_string "SUSE Test";
        send_key 'tab';
        wait_screen_change { type_string "$mail_box" };
        send_key 'tab';
        wait_screen_change { type_string "$mail_passwd" };
        wait_still_screen(2, 4);
        send_key_until_needlematch('thunderbird_configure_manually', 'tab', 4, 2);
        send_key 'spc';    # configure manually
        wait_still_screen(2, 4);
        save_screenshot;
        send_key 'tab';    # scroll page down to see configuration options
        assert_and_click 'thunderbird_know-your-rights';
    }
    else {
        send_key "alt-n";
        wait_still_screen(2, 4);
        type_string "SUSE Test";
        send_key "alt-e";
        wait_screen_change { type_string "$mail_box" };
        send_key "alt-p";
        wait_screen_change { type_string "$mail_passwd" };
        send_key "alt-c";
    }

    if ($proto eq 'pop') {
        # make sure imap icon is on top of the page
        if (!check_screen 'thunderbird_wizard-imap-selected', 3) {
            send_key_until_needlematch('thunderbird_wizard_imap_on_top', 'tab');
        }
        assert_and_click 'thunderbird_wizard-imap-selected';
        assert_and_click 'thunderbird_wizard-imap-pop-open';
        if (is_tumbleweed) {
            assert_and_click 'thunderbird_SSL_pop3-selection-click-TW';
            assert_and_click 'thunderbird_SSL_auth_click';
            assert_and_click 'thunderbird_wizard-pop-done';
        }
        else {
            # If use multimachine, select correct needles to configure thunderbird.
            if ($hostname eq 'client') {
                assert_and_click 'thunderbird_SSL_auth_click';
                wait_still_screen(2);
                send_key 'down';
                send_key 'ret';
            }
            assert_screen "thunderbird_wizard-$proto-selected";
        }
    }

    if ($new_gui) {
        # If use multimachine, select correct needles to configure thunderbird.
        if ($hostname eq 'client') {
            send_key 'end';    # go to the bottom to see whole manual configuration
            if (check_screen 'thunderbird_in-hostname-start-with-dot', 3) {
                record_info 'bsc#1191866';
                # have to edit both hostnames
                assert_and_click 'thunderbird_in-hostname-start-with-dot';
                send_key 'delete';
                assert_and_click 'thunderbird_out-hostname-start-with-dot';
                send_key 'delete';
            }
            if (check_screen 'thunderbird_username') {
                record_info 'bsc#1191853';
                assert_and_click 'thunderbird_username';
                send_key 'ctrl-a';
                type_string 'admin';
            }
            send_key_until_needlematch 'thunderbird_wizard-retest', 'tab';
            assert_and_click 'thunderbird_wizard-retest';
            send_key_until_needlematch 'thunderbird_wizard-done', 'tab', 16, 1;
            assert_and_click 'thunderbird_wizard-done';
            wait_still_screen(2, 4);
            assert_and_click 'thunderbird_SSL_done_config' unless check_screen('thunderbird_confirm_security_exception');
            assert_and_click "thunderbird_confirm_security_exception";
            wait_still_screen(2);
            assert_and_click 'thunderbird_account-processed' if ($proto eq 'pop' && check_screen 'thunderbird_account-processed');
            assert_and_click 'thunderbird_finish';
            assert_and_click "thunderbird_skip-system-integration";
            assert_and_click "thunderbird_get-messages";
        }
        else {
            assert_and_click 'thunderbird_startssl-selected-for-imap';
            wait_still_screen(1);
            assert_and_click 'thunderbird_security-select-none';
            wait_still_screen(1);
            assert_and_click 'thunderbird_startssl-selected-for-smtp';
            wait_still_screen(1);
            assert_and_click 'thunderbird_security-select-none';
            if (check_screen 'thunderbird_username') {
                record_info 'bsc#1191853';
                assert_and_click 'thunderbird_username';
                send_key 'ctrl-a';
                type_string 'admin';
            }
            send_key_until_needlematch 'thunderbird_wizard-retest', 'tab';
            assert_and_click 'thunderbird_wizard-retest';
            send_key_until_needlematch 'thunderbird_wizard-done', 'tab', 16, 1;
            assert_and_click 'thunderbird_wizard-done';
            wait_still_screen(2);
            send_key 'end';    # go to the bottom to see whole button and checkbox
            wait_still_screen(2);
            assert_and_click 'thunderbird_I-understand-the-risks';
            assert_and_click 'thunderbird_risks-done';
            wait_still_screen(2);
            assert_and_click 'thunderbird_account-processed' if ($proto eq 'pop' && check_screen 'thunderbird_account-processed');
            assert_and_click 'thunderbird_finish';
            # skip additional integrations
            assert_and_click "thunderbird_skip-system-integration" if check_screen 'thunderbird_skip-system-integration', 10;
            assert_and_click "thunderbird_get-messages";
        }
    }
    else {
        # If use multimachine, select correct needles to configure thunderbird.
        if ($hostname eq 'client') {
            send_key_until_needlematch 'thunderbird_SSL_done_config', 'alt-t', 5, 2;
            wait_still_screen(2);
            assert_and_click "thunderbird_SSL_done_config";
            wait_still_screen(3);
            assert_and_click 'thunderbird_SSL_done_config' unless check_screen('thunderbird_confirm_security_exception');
            assert_and_click "thunderbird_confirm_security_exception";
            assert_and_click "thunderbird_skip-system-integration";
            assert_and_click "thunderbird_get-messages";
        }
        else {
            assert_and_click 'thunderbird_startssl-selected-for-imap';
            wait_still_screen(1);
            assert_and_click 'thunderbird_security-select-none';
            wait_still_screen(1);
            assert_and_click 'thunderbird_startssl-selected-for-smtp';
            wait_still_screen(1);
            assert_and_click 'thunderbird_security-select-none';
            assert_and_click 'thunderbird_wizard-retest';
            assert_and_click 'thunderbird_wizard-done';
            assert_and_click 'thunderbird_I-understand-the-risks';
            assert_and_click 'thunderbird_risks-done';
            # skip additional integrations
            assert_and_click "thunderbird_skip-system-integration";
            assert_and_click "thunderbird_get-messages";
        }
    }
}

=head2 tb_send_message
 tb_send_message($account);
Test sending an email using Thunderbird.
C<$proto> can be C<pop> or C<imap>.
C<$account> can be C<internal_account_A> or C<internal_account_B> or C<internal_account_C> or C<internal_account_D>.
Returns email subject.
=cut

sub tb_send_message {
    my $hostname = get_var('HOSTNAME') // '';
    my ($self, $proto, $account) = @_;
    my $config = $self->getconfig_emailaccount;
    my $mailbox = $config->{$account}->{mailbox};
    my $mail_passwd = $config->{$account}->{passwd};
    my $mail_subject = $self->get_dated_random_string(4);

    send_key "ctrl-m";
    assert_screen "thunderbird_mail-compose-message";
    wait_screen_change { type_string "$mailbox" };

    send_key "alt-s";
    wait_screen_change { type_string "$mail_subject this is a test mail" };

    send_key "tab";
    type_string "Test email send and receive.";
    assert_and_click "thunderbird_send-message";
    wait_still_screen(2, 4);

    if ($hostname eq 'client') {
        while (1) {
            my @tags = qw(thunderbird_attachment_reminder thunderbird_SSL_error_security_exception thunderbird_confirm_security_exception thunderbird_maximized_send-message thunderbird_cancel thunderbird_get-messages);
            wait_still_screen(5, 10);
            assert_screen(\@tags);
            click_lastmatch;
            last if match_has_tag('thunderbird_get-messages');
        }
    }
    else {
        while (1) {
            wait_still_screen(5, 10);
            assert_screen [qw(thunderbird_sent-folder-appeared thunderbird_cancel)];
            click_lastmatch if match_has_tag('thunderbird_cancel');
            last if match_has_tag('thunderbird_sent-folder-appeared');
        }
    }

    return $mail_subject;
}

=head2 tb_check_email
 tb_check_email($mail_search);
Check for new emails.
C<$mail_search> may be an email subject to search for.
=cut

sub tb_check_email {
    my ($self, $mail_search) = @_;

    wait_still_screen 2;
    send_key "shift-f5";
    wait_still_screen 2;
    send_key "ctrl-shift-k";
    wait_still_screen 2, 3;
    type_string "$mail_search";
    wait_still_screen 2, 3;
    send_key_until_needlematch "thunderbird_sent-message-received", 'shift-f5', 5, 30;

    # delete the message
    assert_and_click "thunderbird_select-message";
    wait_still_screen 2;
    send_key 'delete';
    wait_still_screen 2;
    send_key "ctrl-shift-k";
    wait_still_screen 2, 3;
    send_key 'delete';
}
