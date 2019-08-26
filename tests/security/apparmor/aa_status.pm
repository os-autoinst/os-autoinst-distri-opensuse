# Copyright (C) 2018 SUSE LLC
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
# Summary: Test the basic information output function for apparmor using
# aa-status.
# - Check if apparmor is active
# - Run aa-status, check the output for strings about modules/profiles/processes
# and strings enforced, complain, unconfined and loaded.
# Maintainer: Wes <whdu@suse.com>
# Tags: poo#36874, poo#44912

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use services::apparmor;

sub run {
    select_console 'root-console';
    services::apparmor::check_service();
    services::apparmor::check_aa_status();
}

1;
