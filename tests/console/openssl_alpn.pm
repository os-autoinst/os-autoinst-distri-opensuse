# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use strict;
use testapi;

sub run() {
    # FATE#320292 - Application-Layer Protocol Negotiation (ALPN) support for openssl
    select_console 'root-console';

    assert_script_run 'openssl req -newkey rsa:2048 -nodes -keyout domain.key -x509 -days 365 -out domain.crt -subj "/C=CZ/L=Prague/O=SUSE/CN=alpn.suse.cz"';

    type_string "openssl s_server -key domain.key -cert domain.crt -alpn http\n";
    save_screenshot;

    select_console 'user-console';
    validate_script_output 'openssl s_client -alpn http < /dev/null', sub { m/ALPN protocol: http/ };

    select_console 'root-console';
    send_key "ctrl-c";    # terminate `openssl s_server'
    save_screenshot;
}

1;
# vim: set sw=4 et:
