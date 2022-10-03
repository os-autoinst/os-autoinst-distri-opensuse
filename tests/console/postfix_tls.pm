# SUSE's openQA tests
#
# Copyright 2017-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: postfix cyrus-sasl cyrus-sasl-saslauthd mailx
# Summary: Test Postfix mail server with SSL enabled
# Note: The test case can be run separately for postfix sanity test,
#       or run as stand-alone mail server (together with dovecot)
#       in multi-machine test scenario if MAIL_SERVER var set.
# Maintainer: QE Security <none@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use mailtest;

sub run {
    my $self = shift;
    my $postfix_conf = "/etc/postfix/main.cf";
    my $postfix_cert = "/etc/postfix/ssl/postfix.crt";
    my $postfix_key = "/etc/postfix/ssl/postfix.key";

    select_console "root-console";
    prepare_mail_server;

    # Install postfix and required packages
    zypper_call "in postfix cyrus-sasl cyrus-sasl-saslauthd mailx";

    # Configure postfix with TLS support (only smtpd)
    assert_script_run "curl " . data_url('postfix/main.cf') . " -o $postfix_conf";
    assert_script_run "curl " . data_url('openssl/mail-server-cert.pem') . " -o $postfix_cert";
    assert_script_run "curl " . data_url('openssl/mail-server-key.pem') . " -o $postfix_key";
    assert_script_run "sed -i 's/^#tlsmgr/tlsmgr/' /etc/postfix/master.cf";
    systemctl "restart saslauthd.service";
    systemctl "is-active saslauthd.service";
    systemctl "restart postfix.service";
    systemctl "is-active postfix.service";

    # Print service status for debugging
    systemctl "-l status saslauthd.service 2>&1 | tee /dev/$serialdev";
    systemctl "-l status postfix.service 2>&1 | tee /dev/$serialdev";
    script_run "(ss -nltp | grep master) 2>&1 | tee /dev/$serialdev";

    systemctl 'stop ' . $self->firewall;

    # Send testing mail
    mailx_setup(ssl => "yes", host => $mail_server_name);
    mailx_send_mail(subject => "openQA Testing", to => "$username\@$mail_server_name");

    # Verify mail received
    assert_script_run "postfix flush; grep 'openQA Testing' /var/mail/$username";
}

1;
