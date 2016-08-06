# Copyright (C) 2015 SUSE Linux Products GmbH
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
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use strict;
use base 'basetest';
use testapi;

sub run {

    select_console('root-console');
    if (get_var('DROP_PERSISTENT_NET_RULES')) {
        type_string "rm -f /etc/udev/rules.d/70-persistent-net.rules\n";
    }

    diag('switch to x3270');
    select_console('x3270');
    save_screenshot;
    diag('and back');
    select_console('root-console');
    save_screenshot;
    diag('now poweroff');

    save_screenshot;
    if (get_var('BACKEND', 's390x')) {
        ## if we execute poweroff synchronously we will loose the current
        ## console connected over ssh and confuse the backend consoles, i.e. we
        ## can't switch back to x3270 to control the machine and such
        ## this should make the machine shutdown and it does but it does not
        ## show me the "reached target shutdown" in x3270 but it does when
        ## connecting manyually, trying different workaround
        #type_string "(sleep 3 && poweroff &)\n";
        #diag('before select_console 3270');
        ## all this will stall us, I don't know how to go back to the x3270, it
        ## should be still there
        #save_screenshot;
        #select_console('x3270');
        #save_screenshot;
        ## TODO although the x3270 is displayed it does not show the shutdown
        ## target reached. Reconnecting manually shows it however?!?
        ## workaround to make sure last line is shown
        #console('x3270')->sequence_3270("String(\"#cp term more 0 0\")", "ENTER", "ENTER", "ENTER", "ENTER",);
        #my $r;
        #eval {
        #    $r = console('x3270')->expect_3270(output_delim => qr/Reached target Shutdown/, timeout => 30);
        #};
        #diag "Could not find shutdown target, continuing regardless" unless $r;
        #    #diag('WORKAROUND: Just wait some time to expect the machine to be down before returning and killing the machine in next bootloader');
        ##sleep 60;
        #diag('after select_console 3270');

        ## TODO the following hangs, maybe iucvconn is already down? How can we
        ## check? Should we take a look in the process table for the ssh
        ## process?
        diag('kill serial ssh connection to be able to reconnect later');
        console('iucvconn')->kill_ssh;

        # TODO if possible here we should go back to x3270 to see something
        # see http://lord.arch/tests/2554#step/bootloader_s390/1

        ##diag('reset_consoles');
        ##reset_consoles;
        #diag('before screenshot');
        ## ok so even making a screenshot will not work here, need to reset
        ## consoles then?
        ## the following reset_consoles also does not work, maybe everything is
        ## blocked because of the vanished ssh connection over which we
        ## executed shutdown?
        #reset_consoles;
        #save_screenshot;
        #diag('after screenshot');
        #select_console('x3270');
        #console('x3270')->sequence_3270("String(\"#cp term more 0 0\")", "ENTER", "ENTER", "ENTER", "ENTER",);
        #console('x3270')->sequence_3270("String(\"#cp i cms\")", "ENTER", "ENTER", "ENTER", "ENTER",);
    }
    else {
        type_string "poweroff\n";
        assert_shutdown;
    }
    diag('should be done with shutdown');
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
