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

use base "consoletest";
use xen;
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console 'root-console';
    opensusebasetest::select_serial_terminal();
    my $hypervisor = get_required_var('HYPERVISOR');

    record_info "XML", "Export the XML from virsh and convert it into Xen config file";
    assert_script_run "ssh root\@$hypervisor 'virsh dumpxml $_ > $_.xml'"                         foreach (keys %xen::guests);
    assert_script_run "ssh root\@$hypervisor 'virsh domxml-to-native xen-xl $_.xml > $_.xml.cfg'" foreach (keys %xen::guests);

    record_info "Name", "Change the name by adding suffix _xl";
    assert_script_run "ssh root\@$hypervisor \"sed -rie 's/(name = \\W)/\\1xl-/gi' $_.xml.cfg\"" foreach (keys %xen::guests);
    assert_script_run "ssh root\@$hypervisor 'cat $_.xml.cfg | grep name'"                       foreach (keys %xen::guests);

    record_info "UUID", "Change the UUID by using f00 as three first characters";
    assert_script_run "ssh root\@$hypervisor \"sed -rie 's/(uuid = \\W)(...)/\\1f00/gi' $_.xml.cfg\"" foreach (keys %xen::guests);
    assert_script_run "ssh root\@$hypervisor 'cat $_.xml.cfg | grep uuid'"                            foreach (keys %xen::guests);

    record_info "Start", "Start the new VM";
    assert_script_run "ssh root\@$hypervisor xl create $_.xml.cfg" foreach (keys %xen::guests);
    assert_script_run "ssh root\@$hypervisor xl list xl-$_"        foreach (keys %xen::guests);

    record_info "SSH", "Test that the new VM listens on SSH";
    script_retry "ssh root\@$hypervisor 'nmap $_ -PN -p ssh | grep open'", delay => 30, retry => 6 foreach (keys %xen::guests);

}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

