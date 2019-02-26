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

# Summary: supportserver and supportserver generator implementation
# Maintainer: Pavel Sladek <psladek@suse.com>

use strict;
use warnings;
use base 'basetest';
use testapi;

sub run {

    unless (get_var("BOOTFROM") eq 'c') {
        check_screen("inst-bootmenu", 10);
        send_key "ret";    #faster boot if boot from cd
    }
    assert_screen("bootloader", 10);
    send_key "ret";        #faster boot

}

sub test_flags {
    return {fatal => 1};
}

1;

