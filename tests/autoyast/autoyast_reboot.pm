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

# G-Summary: merge of sles11sp4 autoyast test, base commit
# G-Maintainer: Pavel Sladek <psladek@suse.cz>

use strict;
use base 'basetest';
use testapi;

sub run {
    my $self = shift;


    type_string("shutdown -r now\n");

    #obsoletes installation/autoyast_reboot.pm
    assert_screen("bios-boot",     900);
    assert_screen("autoyast-boot", 20);



##-> into installation/first_boot.pm
    #     assert_screen("autoyast-boot", 200);#both for PXE and ISO boot
    #
    #     my $ret = assert_screen("autoyast-system-login", 1000);
    #

}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return {important => 1};
}

1;

# vim: set sw=4 et:
