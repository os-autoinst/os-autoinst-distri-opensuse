# Copyright (C) 2014,2015 SUSE Linux GmbH
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

use strict;
use base "y2logsstep";

use testapi;
use registration;
use utils qw/assert_screen_with_soft_timeout/;

sub run() {
    if (!get_var("HDD_SCC_REGISTERED")) {
        assert_screen_with_soft_timeout('scc-registration', timeout => 300, soft_timeout => 100, bugref => 'bsc#990254');
    }
    fill_in_registration_data;
}

1;
# vim: set sw=4 et:
