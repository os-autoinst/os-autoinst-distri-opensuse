# SUSE's openQA tests
#
# Copyright 2017-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: postfix fetchmail
# Summary: Test fetchmail works with SSL enabled
# Note: fetchmail connects to a remote mail server (running dovecot)
#   and fetch mails to localhost, then deliver mails (by postfix) to
#   local mailbox.
# Maintainer: QE Security <none@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use mailtest;

sub run {
    my $self = shift;
    my $fetchmailrc = "~/.fetchmailrc";
    my $test_cacert = "~/ca-cert.pem";
    my $mailbox = "/var/mail/$username";
    my $subject = "Testing fetchmail";

    select_console "root-console";
    prepare_mail_client;

    # Install postfix and fetchmail
    zypper_call "in postfix fetchmail";
    systemctl "start postfix.service";
    postfix_dns_lookup_off if $mail_server_ip;
    postfix_config_update;
    assert_script_run "curl " . data_url('openssl/ca-cert.pem') . " -o $test_cacert";

    # Need mailx to send testing mail
    mailx_setup(ssl => "yes", host => $mail_server_name);

    ensure_serialdev_permissions;

    # Switch to user console
    select_console "user-console";

    for my $protocol (qw(pop3 imap)) {
        # Send testing mail to remote mail server
        mailx_send_mail(subject => "$subject", to => "$username\@$mail_server_name");

        # Avoid password input via fetchmailrc
        script_run "echo 'poll $mail_server_name protocol $protocol user \"$username\" password \"$password\"' > $fetchmailrc";
        script_run "cat $fetchmailrc";
        script_run "chmod 0600 $fetchmailrc";

        # Empty local mailbox
        script_run ":> $mailbox";

        # Fetchmail mail to localhost
        assert_script_run "fetchmail -v --ssl --sslcertfile $test_cacert $mail_server_name", 120;
        assert_script_run "grep '$subject' $mailbox";
    }
}

1;
