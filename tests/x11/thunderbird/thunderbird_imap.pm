# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: MozillaThunderbird
# Summary: send an email using SMTP and receive it using IMAP
# - Kill thunderbird, erase all config files
# - Launch thunderbird
# - Create a imap account
# - Send and email to the created mail account
# - Fetch emails, search for the sent email
# - Check that email was well received, delete the message
# - Exit thunderbird
# Maintainer: Paolo Stivanin <pstivanin@suse.com>

use warnings;
use strict;
use testapi;
use utils;
use lockapi qw(mutex_wait);
use base "thunderbird_common";
use x11utils qw(ensure_unlocked_desktop turn_off_gnome_screensaver turn_off_gnome_suspend);

sub run {
    my $self = shift;
    my $account = "internal_account";
    my $hostname = get_var('HOSTNAME') // '';

    mutex_wait('service_setup_done') if get_var('QAM_MAIL_THUNDERBIRD');

    if ($hostname eq 'client') {
        $account = "internal_account_C";
    }
    else {
        $account = "internal_account_A";
    }

    mouse_hide(1);

    # clean up and start thunderbird
    x11_start_program("xterm -e \"killall -9 thunderbird; find ~ -name *thunderbird | xargs rm -rf;\"", valid => 0);
    my $success = eval { x11_start_program("thunderbird", match_timeout => 120); 1 };
    unless ($success) {
        force_soft_failure "bsc#1131306";
    } else {
        $self->tb_setup_account('imap', $account);

        my $mail_subject = $self->tb_send_message('imap', $account);
        $self->tb_check_email($mail_subject);

        # exit Thunderbird
        send_key "ctrl-q";
    }
}

1;

