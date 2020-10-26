# Copyright (C) 2014-2020 SUSE LLC
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
# Summary: performing extra actions specific to sle 15 which are not available normally
# - Stop packagekit service
# Maintainer: Rodion Iafarov <riafarov@suse.com>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils 'pkcon_quit';
use version_utils 'is_sle';

sub run {
    return unless is_sle('15+');
    select_console('root-console');
    # Stop packagekit
    pkcon_quit;
}

1;
