# Copyright (C) 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Setup ZNC IRC bouncer as proxy to freenode
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base 'consoletest';
use strict;
use testapi;
use utils qw(zypper_call systemctl);

sub run {
    select_console('root-console');
    zypper_call('in znc');

    script_run("sudo -u znc znc --makeconf | tee /dev/$serialdev; echo zncconf-status-\$? > /dev/$serialdev", 0);

    wait_serial('Listen on port') || die "znc --makeconf failed";
    type_string("12345\n");

    wait_serial('Listen using SSL');
    type_string("yes\n");

    wait_serial('Listen using both IPv4 and IPv6');
    type_string("yes\n");

    wait_serial('Username');
    type_string("bernhard\n");

    wait_serial('Enter password');
    type_string("$testapi::password\n");

    wait_serial('Confirm password');
    type_string("$testapi::password\n");

    wait_serial('Nick');
    type_string("\n");

    wait_serial('Alternate nick');
    type_string("\n");

    wait_serial('Ident');
    type_string("\n");

    wait_serial('Real name');
    type_string("Bernhard M. Wiedemann\n");

    wait_serial('Bind host');
    type_string("\n");

    wait_serial('Set up a network');
    type_string("yes\n");

    wait_serial('Name');
    type_string("\n");

    wait_serial('Server host');
    type_string("this.remote.irc.server.does.not.exist\n");

    wait_serial('Server uses SSL');
    type_string("\n");

    wait_serial('Server port');
    type_string("\n");

    wait_serial('Server password');
    type_string("\n");

    wait_serial('Initial channels');
    type_string("\n");

    wait_serial('Launch ZNC now');
    type_string("no\n");

    wait_serial("zncconf-status-0") || die "'znc --makeconf' could not finish successfully";

    systemctl 'start znc';
    systemctl 'status znc';
}

1;

