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
# Summary: This test connects to hypervisor using SSH
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base "consoletest";
use xen;
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = @_;
    select_console 'root-console';
    opensusebasetest::select_serial_terminal();
    my $hypervisor = get_required_var('QAM_XEN_HYPERVISOR');

    # Exchange SSH keys
    assert_script_run "ssh-keygen -t rsa -P '' -C 'localhost' -f ~/.ssh/id_rsa";
    assert_script_run "ssh-keyscan $hypervisor > ~/.ssh/known_hosts";
    exec_and_insert_password "ssh-copy-id root\@$hypervisor";

    # Do the same for normal user because of GUI software
    assert_script_run "sudo -u $testapi::username sh -c \"ssh-keygen -t rsa -P '' -C 'localhost' -f /home/$testapi::username/.ssh/id_rsa\"";
    assert_script_run "sudo -u $testapi::username sh -c \"ssh-keyscan $hypervisor > /home/$testapi::username/.ssh/known_hosts\"";
    exec_and_insert_password "sudo -u $testapi::username sh -c \"ssh-copy-id root\@$hypervisor\"";

    # Test the connection
    assert_script_run "ssh root\@$hypervisor 'hostname -f'";
    assert_script_run "ssh root\@$hypervisor 'zypper -n in iputils'";
}

sub test_flags {
    return {fatal => 1, milestone => 0};
}

1;

