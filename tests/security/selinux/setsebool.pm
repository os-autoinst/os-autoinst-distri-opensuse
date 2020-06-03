# Copyright (C) 2020 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.
#
# Summary: Test "# setsebool" command with options "-P / -N" can work
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#63751, tc#1741287

use base 'opensusebasetest';
use power_action_utils "power_action";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = @_;
    my $test_boolean = "fips_mode";

    select_console "root-console";

    # list and verify some (not all as it changes often) boolean(s)
    validate_script_output(
        "getsebool -a",
        sub {
            m/
            authlogin_.*\ -->\ off.*
            daemons_.*\ -->\ off.*
            domain_.*\ -->\ on.*
            selinuxuser_.*\ -->\ off.*
            selinuxuser_.*\ -->\ on.*/sx
        });

    # test option "-P": to set boolean value "off/on"
    assert_script_run("setsebool -P $test_boolean 0");
    validate_script_output("getsebool $test_boolean", sub { m/${test_boolean}\ -->\ off/ });
    assert_script_run("setsebool -P $test_boolean 1");
    validate_script_output("getsebool $test_boolean", sub { m/${test_boolean}\ -->\ on/ });

    # reboot and check again
    power_action("reboot", textmode => 1);
    $self->wait_boot;
    select_console "root-console";

    validate_script_output("getsebool $test_boolean", sub { m/${test_boolean}\ -->\ on/ });

    # test option "-N": to set boolean value "off/on"
    assert_script_run("setsebool -N $test_boolean 0");
    validate_script_output("getsebool $test_boolean", sub { m/${test_boolean}\ -->\ off/ });

    # reboot and check again
    power_action("reboot", textmode => 1);
    $self->wait_boot;
    select_console "root-console";

    validate_script_output("getsebool $test_boolean", sub { m/${test_boolean}\ -->\ on/ });
}

1;
