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

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;

sub run {

    my $self         = shift;
    my $mail_subject = $self->get_dated_random_string(4);
    #Setup account account A, and use it to send a meeting
    #send meet request by account A
    $self->setup_imap("internal_account_A");
    $self->send_meeting_request("internal_account_A", "internal_account_B", $mail_subject);
    assert_screen "evolution_mail-ready", 60;
    # Exit
    send_key "alt-f";
    send_key "q";
    wait_still_screen;

    #login with account B and check meeting request.
    $self->setup_imap("internal_account_B");
    $self->check_new_mail_evolution($mail_subject, "internal_account_B", "imap");
    wait_still_screen;
    # Exit
    send_key "ctrl-q";

}

1;
