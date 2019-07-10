# Copyright (C) 2018-2019 SUSE LLC
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
# Summary: Enforce a disabled profile with aa-enforce. Test uses nscd as base.
# Disables nscd profile using aa-disable, then validates by checking status by aa-status.
# Maintainer: Wes <whdu@suse.com>
# Tags: poo#36877, tc#1621145

use strict;
use warnings;
use base "apparmortest";
use testapi;
use utils;

sub run {
    my ($self) = @_;

    my $executable_name = "/usr/sbin/nscd";
    my $profile_name    = "usr.sbin.nscd";
    my $named_profile   = "";
    #select_console 'root-console';

    systemctl('restart apparmor');

    validate_script_output "aa-disable $executable_name", sub {
        m/Disabling.*nscd/;
    };

    # Recalculate profile name in case
    $named_profile = $self->get_named_profile($profile_name);

    # Check if /usr/sbin/ntpd is really disabled
    die "$executable_name should be disabled"
      if (script_run("aa-status | sed 's/[ \t]*//g' | grep -x $named_profile") == 0);

    validate_script_output "aa-enforce $executable_name", sub {
        m/Setting.*nscd to enforce mode/;
    };

    # Check if $named_profile is in "enforce" mode
    $self->aa_status_stdout_check($named_profile, "enforce");
}

1;
