# Copyright (C) 2015-2018 SUSE Linux GmbH
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

# Summary: Boot and login to the supportserver qcow2 image
# Maintainer: Pavel Sladek <psladek@suse.com>

use strict;
use warnings;
use base 'basetest';
use base 'opensusebasetest';
use testapi;
use utils;
use version_utils 'is_desktop_installed';

sub run {
    my ($self) = @_;
    # we have some tests that waits for dvd boot menu timeout and boot from hdd
    # - the timeout here must cover it
    $self->wait_boot(bootloader_time => 80, textmode => !is_desktop_installed);

    # the supportserver image can be different version than the currently tested system
    # so try to login without use of needles
    $self->select_serial_terminal;
}

sub test_flags {
    return {fatal => 1};
}

1;

