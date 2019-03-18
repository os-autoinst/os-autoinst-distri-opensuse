# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Test mutt mail agent with SSL enabled
# Maintainer: Qingming Su <qmsu@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_tumbleweed';
use mailtest;

sub run {
    my $self   = shift;
    my $muttrc = "~/.muttrc";

    select_console "root-console";
    prepare_mail_client;

    # install mutt
    if (is_tumbleweed) {
        zypper_call "in --replacefiles --force-resolution mutt";
    }
    else {
        zypper_call "in mutt";
    }

    assert_script_run "mkdir -p ~/.mutt/cache/headers";
    assert_script_run "mkdir -p ~/.mutt/cache/bodies";
    assert_script_run "curl " . data_url('mutt/muttrc') . " -o $muttrc";
    assert_script_run "curl " . data_url('openssl/ca-cert.pem') . " -o ~/.mutt/certificates";
    assert_script_run "sed -i 's/USER/$username/g' $muttrc";
    assert_script_run "sed -i 's/PASS/$password/g' $muttrc";

    # Send testing mails
    for (1 .. 3) {
        assert_script_run "echo 'Mail body' | mutt -s 'Testing mutt $_' $username\@$mail_server_name";
    }

    # Receive mails
    type_string "mutt\n";

    # check testing mail in mailbox
    assert_screen 'mutt_mailbox';

    # quit mutt
    send_key 'q';
}

1;
