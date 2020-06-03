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
# Summary: Test "#semanage boolean" command with options
#          "-l / -D / -m / -C..." can work
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#64728, tc#1741288

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
        "semanage boolean -l",
        sub {
            m/
            authlogin_.*(off.*,.*off).*
            daemons_.*(off.*,.*off).*
            domain_.*(off.*,.*off).*
            selinuxuser_.*(on.*,.*on).*/sx
        });

    # test option "-m": to set boolean value "off/on"
    assert_script_run("semanage boolean -m --off $test_boolean");
    validate_script_output("semanage boolean -l | grep $test_boolean", sub { m/${test_boolean}.*(off.*,.*off).*Allow.*to.*/ });
    assert_script_run("semanage boolean -m --on $test_boolean");
    validate_script_output("semanage boolean -l | grep $test_boolean", sub { m/${test_boolean}.*(on.*,.*on).*Allow.*to.*/ });

    # reboot and check again
    power_action("reboot", textmode => 1);
    $self->wait_boot;
    select_console "root-console";

    validate_script_output("semanage boolean -l | grep $test_boolean", sub { m/${test_boolean}.*(on.*,.*on).*Allow.*to.*/ });

    # test option "-C": to list boolean local customizations
    validate_script_output(
        "semanage boolean -l -C",
        sub {
            m/
            SELinux.*boolean.*State.*Default.*Description.*
            ${test_boolean}.*(on.*,.*on).*Allow.*to.*
            selinuxuser_execmod.*(on.*,.*on).*Allow.*to.*/sx
        });

    # test option "-D": to delete boolean local customizations
    assert_script_run("semanage boolean -D");

    # verify boolean of local customizations was/were deleted
    my $output = script_output("semanage boolean -l -C");
    if ($output) {
        $self->result('fail');
    }

    # clean up: restore the value for "selinuxuser_execmod"
    assert_script_run("semanage boolean --modify --on selinuxuser_execmod");
}

1;
