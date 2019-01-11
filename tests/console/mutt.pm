# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Test basic capabilities of mutt
# Maintainer: Jan Baier <jbaier@suse.cz>

use base 'consoletest';
use strict;
use testapi;
use version_utils qw(is_sle is_tumbleweed is_jeos);
use utils;

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    zypper_call("in mutt", exitcode => [0, 102, 103]) if (is_tumbleweed || is_jeos);

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
    type_string "mutt\na";
    assert_screen 'mutt-message-list';
    type_string "\n";
    assert_screen 'mutt-show-mail';

    record_info 'reply', 'Send a reply to the mail';
    type_string "rOHello,\nthanks for the message.\n:x\n";
    assert_screen 'mutt-send-reply';
    type_string "y";
    assert_screen 'mutt-message-sent';

    record_info 'move', 'Move mail to another mailbox';
    type_string "sArchive\n\n";
    assert_screen 'mutt-message-deleted';
    type_string "q";

    #select_console "user-console";
    record_info 'open mailbox', 'Open local mailbox';
    type_string "mutt -f ~/Archive\n";
    assert_screen 'mutt-message-list';
    type_string "q";

    type_string "clear\n";
    script_run 'rm -r ~/Archive';
    save_screenshot;

    $self->select_serial_terminal;
    record_info 'postfix log', 'Check if the mail was really send';
    validate_script_output 'journalctl --no-pager -u postfix', sub { m/postfix\/qmgr.*<nimda\@localhost>/ };

    select_console "root-console";
}

sub test_flags {
    return {fatal => 0};
}

1;
