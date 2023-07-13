# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: iproute2 hostname expect postfix dovecot telnet
# Summary: Setup mail server for testing "usr.lib.dovecot.*" & "usr.sbin.dovecot":
#          set up it with Postfix and Dovecot and create a testing mail.
# - Set up mail server with Postfix and Dovecot
# - Install telnet
# - Using telnet, send an email through smtp server
# - Upload mail logs as reference
# Maintainer: QE Security <none@suse.de>
# Tags: poo#46235, poo#46238, tc#1695947, tc#1695943

use base "apparmortest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';

sub run {
    my ($self) = shift;

    # Set up mail server with Postfix and Dovecot
    $self->setup_mail_server_postfix_dovecot();

    # Install telnet
    zypper_call("--no-refresh in telnet");

    unless (is_sle('<=12-sp2')) {

        # Create a testing mail with telnet smtp
        $self->send_mail_smtp();

        # Upload mail logs for reference
        $self->upload_logs_mail();
    }
}

sub test_flags {
    return {milestone => 1};
}

1;
