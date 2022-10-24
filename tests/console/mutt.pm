# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: mutt wget
# Summary: Test basic capabilities of mutt
# - Install mutt and wget (if necessary)
# - Check if mutt has built in support for imap and smtp
# - Get sample configuration from datadir
# - Send email and check postfix log
# - Open mutt and check for emails
# - Reply test email and check sent messages
# - Archive mail message and quit
# - Open local mailbox, check and quit
# - Cleanup
# - Save screenshot
# Maintainer: Jan Baier <jbaier@suse.cz>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use version_utils qw(is_sle);
use utils;

sub run {
    select_serial_terminal;

    zypper_call("in mutt", exitcode => [0, 102, 103]);
    zypper_call("in wget", exitcode => [0, 102, 103]);

    # Mutt is Mutt (bsc#1094717) and has build in support for IMAP and SMTP
    validate_script_output 'mutt -v', sub { m/\+USE_IMAP/ && m/\+USE_SMTP/ && not m/NeoMutt/ };

    # Create initial "sane" configuration and begin the test
    assert_script_run 'wget -O ~/.muttrc ' . data_url('console/muttrc');
    assert_script_run 'sed -i -e "s/nimda/admin/" ~/.muttrc';

    record_info 'send mail', 'Write new mail from command line';
    assert_script_run 'echo -e "Hello,\nthis is message from admin." | mutt -s "Hello from openQA" -- nimda@localhost';

    record_info 'postfix log', 'Check if the mail was really send';
    validate_script_output 'journalctl --no-pager -u postfix', sub { m/postfix\/qmgr.*<admin\@localhost>/ };

    select_console "user-console";
    assert_script_run 'wget -O ~/.muttrc ' . data_url('console/muttrc');
    assert_script_run 'sed -i -e "/ssl_ca_certificates_file/d" ~/.muttrc' if is_sle('<=12-SP2');

    record_info 'receive mail', 'Run mutt as a user to read the mail';
    enter_cmd "mutt";
    send_key 'a';
    assert_screen 'mutt-message-list';
    send_key 'ret';
    assert_screen 'mutt-show-mail';

    record_info 'reply', 'Send a reply to the mail';
    enter_cmd "rOHello,\nthanks for the message.\n:x";
    assert_screen 'mutt-send-reply';
    type_string "y";
    assert_screen 'mutt-message-sent';

    record_info 'move', 'Move mail to another mailbox';
    enter_cmd "sArchive\n";
    assert_screen 'mutt-message-deleted';
    type_string "q";

    #select_console "user-console";
    record_info 'open mailbox', 'Open local mailbox';
    enter_cmd "mutt -f ~/Archive";
    assert_screen 'mutt-message-list';
    type_string "q";

    enter_cmd "clear";
    script_run 'rm -r ~/Archive';
    save_screenshot;

    select_serial_terminal;
    record_info 'postfix log', 'Check if the mail was really send';
    validate_script_output 'journalctl --no-pager -u postfix', sub { m/postfix\/qmgr.*<nimda\@localhost>/ };

    select_console "root-console";
}

1;
