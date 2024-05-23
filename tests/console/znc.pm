# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: znc
# Summary: Setup ZNC IRC bouncer as proxy to freenode
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils qw(zypper_call systemctl);

sub run {
    select_console('root-console');
    zypper_call('in znc');

    script_run("su znc -s /bin/bash -c \"\$(grep ExecStart= /usr/lib/systemd/system/znc.service | sed 's/ExecStart=//') --makeconf\" | tee /dev/$serialdev; echo zncconf-status-\$? > /dev/$serialdev", 0);

    wait_serial('Listen on port') || die "znc --makeconf failed";
    enter_cmd("12345");

    wait_serial('Listen using SSL');
    enter_cmd("yes");

    wait_serial('Listen using both IPv4 and IPv6');
    enter_cmd("yes");

    wait_serial('Username');
    enter_cmd("bernhard");

    wait_serial('Enter password');
    enter_cmd("$testapi::password");

    wait_serial('Confirm password');
    enter_cmd("$testapi::password");

    wait_serial('Nick');
    send_key 'ret';

    wait_serial('Alternate nick');
    send_key 'ret';

    wait_serial('Ident');
    send_key 'ret';

    wait_serial('Real name');
    enter_cmd("Bernhard M. Wiedemann");

    wait_serial('Bind host');
    send_key 'ret';

    wait_serial('Set up a network');
    enter_cmd("yes");

    wait_serial('Name');
    send_key 'ret';

    wait_serial('Server host');
    enter_cmd("this.remote.irc.server.does.not.exist");

    wait_serial('Server uses SSL');
    send_key 'ret';

    wait_serial('Server port');
    send_key 'ret';

    wait_serial('Server password');
    send_key 'ret';

    wait_serial('Initial channels');
    send_key 'ret';

    wait_serial('Launch ZNC now');
    enter_cmd("no");

    wait_serial("zncconf-status-0") || die "'znc --makeconf' could not finish successfully";

    systemctl 'start znc';
    systemctl 'status znc';
}

1;

