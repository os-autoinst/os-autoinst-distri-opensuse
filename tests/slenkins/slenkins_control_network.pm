# Copyright (C) 2015 SUSE Linux GmbH
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

# G-Summary: improved slenkins
#    - do not parse node files, everything is configured via variables
#    - import-slenkins-testsuite.pl script for importing the variables
#    - run control node on support server
# G-Maintainer: Vladimir Nadvornik <nadvornik@suse.cz>

use strict;
use base 'basetest';
use testapi;
use lockapi;
use mmapi;
use mm_network;

sub run {
    my $self = shift;

    # this is an alternative setup for running independent slenkins control node without support server
    # normally, this is done as part of support server setup

    configure_default_gateway;
    configure_static_ip('10.0.2.1/24');
    configure_static_dns(get_host_resolv_conf());

    script_output("
        zypper -n --no-gpg-checks ar '" . get_var('SLENKINS_TESTSUITES_REPO') . "' slenkins_testsuites
        zypper -n --no-gpg-checks ar '" . get_var('SLENKINS_REPO') . "' slenkins
    ", 100);
}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
