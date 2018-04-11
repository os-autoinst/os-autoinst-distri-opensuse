# SUSE's openQA tests
#
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Testopia Case#1595207 - FIPS: x3270

# Summary: x3270 for SSL support testing, with openssl s_server running on local system
# Maintainer: Wnereiz <wnereiz@eienteiland.org>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $cert_file     = '/tmp/server.cert';
    my $key_file      = '/tmp/server.key';
    my $tracelog_file = '/tmp/x3270-trace.log';

    select_console 'root-console';

    # Install x3270
    zypper_call "install x3270";

    #Generate self-signed x509 certificate
    type_string
"openssl req -new -x509 -newkey rsa:2048 -keyout $key_file -days 3560 -out $cert_file -nodes -subj \"/C=CN/ST=BJ/L=BJ/O=SUSE/OU=QA/CN=suse/emailAddress=test\@suse.com\" 2>&1 | tee /dev/$serialdev\n";

    wait_serial "writing new private", 120 || die "openssl req output doesn't match";

    #Workaround for avoiding missing charactors in following commands
    for (1 ... 20) {
        send_key "ret";
    }

    #Setup openssl s_server
    type_string "openssl s_server -accept 8443 -cert $cert_file -key $key_file 2>&1 | tee /dev/$serialdev\n";

    wait_serial "ACCEPT", 10 || die "openssl s_server output doesn't match";

    select_console 'x11';

    x11_start_program('xterm');
    mouse_hide(1);

    #Launch x3270
    type_string "x3270 -trace -tracefile $tracelog_file L:localhost:8443\n";
    assert_screen 'x3270_fips_launched';

    for (1 ... 3) {
        send_key "alt-f4";
    }
    assert_screen 'generic-desktop';

    #Terminate openssl s_server
    select_console 'root-console';
    send_key "ctrl-c";
    clear_console;

    type_string "cat $tracelog_file | tee /dev/$serialdev\n";
    wait_serial "TLS/SSL tunneled connection complete", 5 || die "x3270 output doesn't match";

    #Clean
    script_run "rm -f $tracelog_file $cert_file $key_file";

    #Exit and return to x11
    send_key "ctrl-d";
    send_key "ctrl-d";
    select_console 'x11';
}

1;
