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
    my $hypervisor = get_required_var('HYPERVISOR');

    # Remove old files
    assert_script_run 'rm ~/.ssh/* || true';

    # Generate the key pair
    assert_script_run "ssh-keygen -t rsa -P '' -C 'localhost' -f ~/.ssh/id_rsa";

    # Configure the Master socket
    assert_script_run "echo 'ControlMaster auto
    ControlPath ~/.ssh/ssh_%r_%h_%p
    ControlPersist 86400
    
    Host $hypervisor
      Hostname $hypervisor
      User root

    Host sles*
      ProxyJump $hypervisor
    ' > ~/.ssh/config";

    # Exchange SSH keys
    assert_script_run "ssh-keyscan $hypervisor > ~/.ssh/known_hosts";
    exec_and_insert_password "ssh-copy-id -f root\@$hypervisor";

    # Test the connection
    assert_script_run "ssh root\@$hypervisor hostname -f";

    # Copy that also for normal user
    assert_script_run "install -o $testapi::username -g users -m 0700 -d /home/$testapi::username/.ssh";
    assert_script_run "install -o $testapi::username -g users -m 0600 ~/.ssh/config ~/.ssh/id_rsa ~/.ssh/id_rsa.pub ~/.ssh/known_hosts /home/$testapi::username/.ssh/";
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

