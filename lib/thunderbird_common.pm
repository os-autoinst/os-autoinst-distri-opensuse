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

    assert_and_click "thunderbird_wizard-set-pop" if ($proto eq 'pop');
    assert_screen "thunderbird_wizard-$proto-selected";
    # done
    send_key "alt-d";
    # workaround: for some reasons, when using self signed cert thunderbird doesn't accept the password during setup
    # but does accept it later on. So, we have to click 'done', delete the password, click 'done' again and we are good to go.
    # Of course, we will have to input the password later on (eg when clicking on 'Inbox')
    send_key "alt-p";
    send_key "delete";
    wait_screen_change { send_key "alt-d" };
    if (is_sle) {
        wait_still_screen 5;
        # sometimes "alt-d" doesn't work, so we have to fallback to
        if (check_screen "thunderbird_wizard-send-button") {
            assert_and_click "thunderbird_wizard-send-button";
            wait_still_screen 3;
        }
    }
    # skip additional integrations
    assert_and_click "thunderbird_skip-system-integration";
    wait_still_screen 3;

    # confirm that we accept the self signed cert
    wait_screen_change { send_key "alt-c" };

    assert_and_click "thunderbird_account-inbox";

    if ($proto eq 'pop') {
        # when using POP simply clicking on inbox doesn't show the dialog password, so we have to click on 'Get Messages'
        assert_and_click "thunderbird_get-messages";
    }

    # we now have to input and store the imap password
    assert_and_click "thunderbird_passwd-diag-use-password-manager";
    assert_and_click "thunderbird_passwd-diag-entry";
    wait_screen_change { type_string "$mail_passwd" };
    send_key "ret";
}

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

    # it may happen that the 'send error' dialog is shown before the 'confirm certificate' dialog
    assert_screen([qw(thunderbird_send-message-error thunderbird_incoming-self-signed-cert)]);
    if (match_has_tag("thunderbird_send-message-error")) {
        # in this case the 'compose message' window is in background
        wait_screen_change { send_key "ret" };
        # it may happen that the main window goes in background, therefore we have to make sure that
        # we are dealing with the correct one
        assert_screen([qw(thunderbird_window-is-compose thunderbird_incoming-self-signed-cert)]);
        if (match_has_tag("thunderbird_window-is-compose")) {
            wait_screen_change { send_key "alt-`" };
            wait_screen_change { send_key "alt-c" };
            wait_screen_change { send_key "alt-`" };
        } elsif (match_has_tag("thunderbird_incoming-self-signed-cert")) {
            wait_screen_change { send_key "alt-c" };
        }
        wait_screen_change { send_key "super" };
        assert_and_click "thunderbird_select-compose-window";
    } elsif (match_has_tag("thunderbird_incoming-self-signed-cert")) {
        # in this case the 'compose message' window is in foreground
        wait_screen_change { send_key "alt-c" };
        unless (check_screen("thunderbird_send-message-error")) {
            wait_screen_change { send_key "alt-`" };
        }
        # buggy part, retrying window switch up to 3 times
        if (check_screen("thunderbird-main-window", 5)) {
            wait_screen_change { send_key "alt-`" };
        }
        if (check_screen("thunderbird-main-window", 5)) {
            sleep 5;
            wait_screen_change { send_key "alt-`" };
        }
        if (check_screen("thunderbird-main-window", 5)) {
            sleep 5;
            wait_screen_change { send_key "super" };
            assert_and_click "thunderbird_select-compose-window";
        }
        wait_screen_change { assert_and_click "thunderbird_send-message-error-ok-button" };
    }

    # now the message can be really sent (ctrl-m doesn't always work, so it's more reliable to use assert_and_click)
    wait_screen_change { assert_and_click "thunderbird_compose-send-button" };
    assert_screen "thunderbird_prompt-password";
    wait_screen_change { type_password "$mail_passwd" };
    send_key "ret";

    # if the "sent message can't be saved" dialog shows up, then we agree not to save a copy of the sent message
    if (check_screen("thunderbird_save-message-error", 5)) {
        send_key "alt-n";
    }

    return $mail_subject;
}

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
