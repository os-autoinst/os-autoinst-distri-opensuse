# SUSE's openQA tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: openssl
# Summary: Test ALPN support in openssl
# - Run 'openssl req -newkey rsa:2048 -nodes -keyout domain.key -x509 -days 365
#   -out domain.crt -subj "/C=CZ/L=Prague/O=SUSE/CN=alpn.suse.cz"' and create
#   certificate
# - Run "openssl s_server -key domain.key -cert domain.crt -alpn http" and check
# - Run "openssl s_client -alpn http < /dev/null" and check for "ALPN protocol:
#   http"
# - Send "CTRL-C" and save screenshot
# Maintainer: Michal Nowak <mnowak@suse.com>
# Tags: fate#320292

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console 'root-console';

    zypper_call 'in openssl';
    assert_script_run 'openssl req -newkey rsa:2048 -nodes -keyout domain.key -x509 -days 365 -out domain.crt -subj "/C=CZ/L=Prague/O=SUSE/CN=alpn.suse.cz"';

    clear_console;
    enter_cmd "openssl s_server -key domain.key -cert domain.crt -alpn http";
    assert_screen "openssl-s_server-alpn-accept-connections";

    select_console 'user-console';
    validate_script_output 'openssl s_client -alpn http < /dev/null', sub { m/ALPN protocol: http/ };

    # the openssl server is still running so do not expect a ready prompt
    select_console 'root-console', await_console => 0;
    send_key "ctrl-c";    # terminate `openssl s_server'
    save_screenshot;
}

1;
