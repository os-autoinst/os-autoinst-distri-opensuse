# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Test mailx send/reveive mails with SSL enabled
# Maintainer: Qingming Su <qmsu@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use mailtest;

sub run {
    my $self = shift;

    select_console "root-console";
    prepare_mail_client;

    # Install dovecot package
    zypper_call "in mailx";

    # Send testing mail
    my $subject   = "Testing mailx";
    my $user_mail = "$username\@$mail_server_name";
    mailx_setup(ssl => "yes", host => "$mail_server_name");
    mailx_send_mail(subject => "$subject", to => "$user_mail");

    # Receive mail with pop3s prouser_mailcol
    validate_script_output "echo '$password' | mailx -S pop3-use-starttls -f pop3s://$user_mail", sub { m/$subject/ }, 120;

    # Receive mail with imaps prouser_mailcol
    validate_script_output "echo '$password' | mailx -S imap-use-starttls -f imaps://$user_mail", sub { m/$subject/ }, 120;
}

1;
