# Copyright (C) 2017 SUSE LLC
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

# Summary: Test basic weechat start and stop
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils 'zypper_call';

sub run {
    select_console('root-console');
    zypper_call('in weechat');
    select_console('user-console');
    script_run("weechat; echo weechat-status-\$? > /dev/$serialdev", 0);
    assert_screen('weechat');

    run_weechat_command("/server add znc localhost/12345 -ssl -ssl_verify=0 -username=bernhard/freenode -password=$testapi::password");
    assert_screen('weechat-server-added');

    run_weechat_command("/connect znc");
    assert_screen('weechat-welcome_to_znc');

    run_weechat_command("/query *status");
    type_string("\n");

    run_weechat_command("Version");
    assert_screen('weechat-znc-status-version');

    run_weechat_command("/quit");
    wait_serial("weechat-status-0") || die "'weechat' could not finish successfully";
}

sub run_weechat_command {
    type_string(shift);
    wait_still_screen 2;
    save_screenshot;
    type_string("\n");
}

1;

