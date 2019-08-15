# Copyright (C) 2018-2019 SUSE LLC
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

# Summary: Enforce a disabled profile with aa-enforce.
# - restarts apparmor
# - disables nscd by running aa-disable /usr/sbin/nscd
# - use aa-status to check if nscd is really disabled
# - runs aa-enforce on /usr/bin/nscd to enforce mode and check output
# - runs aa-status and check if nscd is on enforce mode.
# Maintainer: Wes <whdu@suse.com>
# Tags: poo#36877, tc#1621145

use strict;
use warnings;
use base "apparmortest";
use testapi;
use utils;
use services::apparmor;

sub run {
    my ($self) = @_;
    select_console 'root-console';
    services::apparmor::check_aa_enforce($self);
}

1;
