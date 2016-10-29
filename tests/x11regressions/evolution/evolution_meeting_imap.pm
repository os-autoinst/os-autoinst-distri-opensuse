# Evolution tests
#
# Copyright © 2016 SUSE LLC

# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: tc# 1503817: Evolution: Imap Meeting
#   This is used for tc# 1503817, Send the meeting request by evolution and the
#   receiver will get the meeting request with imap protocol.
# Maintainer: Jiawei Sun <JiaWei.Sun@suse.com>

use base "x11regressiontest";
use strict;
use testapi;
use utils;


sub setup {
    my ($self, $i) = @_;
    $self->setup_imap($i);
}

#Setup mail account by auto lookup
sub auto_setup {
    my ($self, $account) = @_;
    my $config        = $self->getconfig_emailaccount;
    my $mail_box      = $config->{$account}->{mailbox};
    my $mail_server   = $config->{$account}->{sendServer};
    my $mail_user     = $config->{$account}->{user};
    my $mail_passwd   = $config->{$account}->{passwd};
    my $mail_sendport = $config->{$account}->{sendport};
    my $mail_recvport = $config->{$account}->{recvport};

    $self->start_evolution($mail_box);
    assert_screen "evolution_wizard-skip-lookup";
    assert_screen "evolution_wizard-account-summary";

    #if used Yahoo account, need disabled Yahoo calendar and tasks
    if ($account eq "Yahoo") {
        send_key "alt-l";
    }
    send_key "$next";
    if (sle_version_at_least('12-SP2')) {
        send_key "$next";    #only in 12-SP2 or later
        send_key "ret";
    }
    assert_screen "evolution_wizard-done";
    send_key "alt-a";
    if (check_screen "evolution_mail-auth") {
        if (sle_version_at_least('12-SP2')) {
            send_key "alt-a";    #disable keyring option, only in SP2 or later
            send_key "alt-p";
        }
        type_string "$mail_passwd";
        send_key "ret";
    }
    if (check_screen "evolution_mail-init-window") {
        send_key "super-up";
    }
    assert_screen "evolution_mail-max-window";
}

sub run() {

    my $self         = shift;
    my $mail_subject = $self->get_dated_random_string(4);
    #Setup account account A, and use it to send a meeting
    #send meet request by account A
    $self->setup("internal_account_A");
    $self->send_meeting_request("internal_account_A", "internal_account_B", $mail_subject);
    assert_screen "evolution_mail-ready", 60;
    # Exit
    send_key "alt-f";
    send_key "q";
    wait_idle;

    #login with account B and check meeting request.
    $self->setup("internal_account_B");
    $self->check_new_mail_evolution($mail_subject, "internal_account_B", "imap");
    wait_idle;
    # Exit
    send_key "ctrl-q";

}

1;
# vim: set sw=4 et:
