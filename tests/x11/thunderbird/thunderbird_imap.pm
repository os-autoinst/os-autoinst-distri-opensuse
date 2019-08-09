# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: send an email using SMTP and receive it using IMAP
# - Kill thunderbird, erase all config files
# - Launch thunderbird
# - Create a imap account
# - Send and email to the created mail acount
# - Fetch emails, search for the sent email
# - Check that email was well received, delete the message
# - Exit thunderbird
# Maintainer: Paolo Stivanin <pstivanin@suse.com>

use warnings;
use strict;
use testapi;
use utils;
use base "thunderbird_common";

sub run {
    my $self    = shift;
    my $account = "internal_account_A";

    mouse_hide(1);
    # clean up and start thunderbird
    x11_start_program("xterm -e \"killall -9 thunderbird; find ~ -name *thunderbird | xargs rm -rf;\"", valid => 0);
    my $success = eval { x11_start_program("thunderbird", match_timeout => 120); 1 };
    unless ($success) {
        force_soft_failure "bsc#1131306";
    } else {
        $self->tb_setup_account('imap', $account);

        my $mail_subject = $self->tb_send_message($account);
        $self->tb_check_email($mail_subject);

        # exit Thunderbird
        send_key "ctrl-q";
    }
}

1;

