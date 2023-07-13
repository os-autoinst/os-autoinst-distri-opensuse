# openssl fips test
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: testing openSSL dhparam and
# s_client/s_server with DHE when in FIPS mode.
# Maintainer: QE Security <none@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_transactional);

sub create_user {
    my $user = $testapi::username;
    my $password = $testapi::password;
    if (script_run("getent passwd $user") != 0) {
        assert_script_run "useradd -m $user";
        assert_script_run "echo '$user:$password' | chpasswd";
    }
    # Make sure user has access to tty group
    my $serial_group = script_output "stat -c %G /dev/$testapi::serialdev";
    assert_script_run "grep '^${serial_group}:.*:${user}\$' /etc/group || (chown $user /dev/$testapi::serialdev && gpasswd -a $user $serial_group)";
}

sub run {
    select_console 'root-console';

    # SLE Micro doesn't have user created by default
    create_user if is_transactional;

    assert_script_run 'openssl req -newkey rsa:2048 -nodes -keyout generatedkey.key -x509 -days 365 -out generatedcert.crt -subj "/C=DE/L=Nue/O=SUSE/CN=security.suse.de"', timeout => 300;
    assert_script_run 'openssl dhparam -out dhparams_2048.pem 2048';
    clear_console;

    enter_cmd 'openssl s_server -key generatedkey.key -cert generatedcert.crt -dhparam dhparams_2048.pem -cipher DHE --accept 44330';
    assert_screen 'openssl-fips-dhparam_accept_conn';

    select_console 'user-console';
    validate_script_output 'openssl s_client -connect localhost:44330 < /dev/null', sub { m/CONNECTED.*/ };

    # the openssl server is still running so do not expect a ready prompt
    select_console 'root-console', await_console => 0;
    send_key "ctrl-c";
}

1;
