# Copyright (C) 2019 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.
#
# Summary: Setup mail server for testing "usr.lib.dovecot.*" & "usr.sbin.dovecot":
#          set up it with Postfix and Dovecot and create a testing mail.
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#46235, poo#46238, tc#1695947, tc#1695943

use base "apparmortest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = shift;

    # Set up mail server with Postfix and Dovecot
    $self->setup_mail_server_postfix_dovecot();

    # Install telnet
    zypper_call("--no-refresh in telnet");

    # Create a testing mail with telnet smtp
    $self->send_mail_smtp();

    # Upload mail logs for reference
    $self->upload_logs_mail();
}

sub test_flags {
    return {milestone => 1};
}

1;
