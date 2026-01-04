# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: MozillaThunderbird
# Summary: send an email using SMTP and receive it using POP
# - Kill thunderbird, erase all config files
# - Launch thunderbird
# - Create a pop account
# - Send and email to the created mail acount
# - Fetch emails, search for the sent email
# - Check that email was well received, delete the message
# - Exit thunderbird
# Maintainer: Paolo Stivanin <pstivanin@suse.com>

use testapi;
use utils;
use x11utils;
use base "thunderbird_common";

sub run {
    my $self = shift;
    my $account = "internal_account";
    my $hostname = get_var('HOSTNAME') // '';
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
        $self->tb_setup_account('pop', $account);

        my $mail_subject = $self->tb_send_message('pop', $account);
        $self->tb_check_email($mail_subject);

        # Test of GTK interfacing with CUPS
        assert_and_click 'thunderbird_inbox';
        assert_and_click 'thunderbird_check-message';
        my $filename = "thunderbird.pdf";
        save_print_file($filename);
        # exit Thunderbird
        assert_and_click 'close_thunderbird';
        x11_start_program(default_gui_terminal());
        validate_script_output("file $filename", sub { m/PDF document/ });
        enter_cmd "exit";
    }
}

1;

