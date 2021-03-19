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
# Package: openssh
# Summary: This test fetch SSH keys of all guests and authorize the client one
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base "consoletest";
use virt_autotest::common;
use virt_autotest::utils;
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $self = shift;
    # Use serial terminal, unless defined otherwise. The unless will go away once we are certain this is stable
    $self->select_serial_terminal unless get_var('_VIRT_SERIAL_TERMINAL', 1) == 0;

    foreach my $guest (keys %virt_autotest::common::guests) {
        record_info "$guest", "Establishing SSH connection to $guest";

        virt_autotest::utils::ssh_copy_id($guest);
        assert_script_run "ssh root\@$guest 'rm /etc/cron.d/qam_cron; hostname'";
    }
    assert_script_run qq(echo -e "PreferredAuthentications publickey\\nControlMaster auto\\nControlPersist 86400\\nControlPath ~/.ssh/ssh_%r_%h_%p" >> ~/.ssh/config);
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

