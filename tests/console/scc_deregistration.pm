# Copyright (C) 2017 SUSE LLC
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

# Summary: Deregister from the SUSE Customer Center
# Maintainer: Qingming Su <qmsu@suse.com>

use strict;
use warnings;
use base "consoletest";
use testapi;
use registration "scc_deregistration";

sub run {
    return unless (get_var('SCC_REGISTER') || get_var('HDD_SCC_REGISTERED'));

    select_console 'root-console';
    scc_deregistration;
}

1;
