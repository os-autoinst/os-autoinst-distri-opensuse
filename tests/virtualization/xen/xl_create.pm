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
# Summary: Export XML from virsh and create new guests in xl stack
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base "x11test";
use xen;
use strict;
use testapi;
use utils;

sub run {
    my ($self) = @_;
    select_console 'x11';
    my $hypervisor = get_required_var('QAM_XEN_HYPERVISOR');
    my $domain     = get_required_var('QAM_XEN_DOMAIN');

    x11_start_program('xterm');
    send_key 'super-up';

    foreach my $guest (keys %xen::guests) {
        record_info "$guest", "Starting to clone $guest to xl-$guest";

        # Export the XML from virsh and convert it into Xen config file
        assert_script_run "ssh root\@$hypervisor 'virsh dumpxml $guest > $guest.xml'";
        assert_script_run "ssh root\@$hypervisor 'virsh domxml-to-native xen-xl $guest.xml > $guest.xml.cfg'";

        # Change the name by adding suffix _xl
        assert_script_run "ssh root\@$hypervisor \"sed -rie 's/(name = \\W)/\\1xl-/gi' $guest.xml.cfg\"";
        assert_script_run "ssh root\@$hypervisor 'cat $guest.xml.cfg | grep name'";

        # Change the UUID by using f00 as three first characters
        assert_script_run "ssh root\@$hypervisor \"sed -rie 's/(uuid = \\W)(...)/\\1f00/gi' $guest.xml.cfg\"";
        assert_script_run "ssh root\@$hypervisor 'cat $guest.xml.cfg | grep uuid'";

        # Start the new VM
        assert_script_run "ssh root\@$hypervisor xl create $guest.xml.cfg";
        assert_script_run "ssh root\@$hypervisor xl list xl-$guest";

        # Test that the new VM listens on SSH
        assert_script_run "while true; do ssh root\@$guest.$domain hostname 2> /dev/null && break; done";

        clear_console;
    }

    wait_screen_change { send_key 'alt-f4'; };

}

sub test_flags {
    return {fatal => 1, milestone => 0};
}

1;

