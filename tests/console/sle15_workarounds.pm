# Copyright (C) 2014-2017 SUSE LLC
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
# Maintainer: Rodion Iafarov <riafarov@suse.com>

use base "consoletest";
use strict;
use testapi;
use utils qw(zypper_call sle_version_at_least);


sub run {
    return unless sle_version_at_least('15');
    select_console 'root-console';
    # Kernel devel packages are not in the dev tools module, so add standard repos
    record_soft_failure('bsc#1053222');    # Once bug is resolved, this code can be removed
    zypper_call('ar http://download.suse.de/ibs/SUSE:/SLE-15:/GA/standard/SUSE:SLE-15:GA.repo');
    zypper_call('--gpg-auto-import-keys ref');
    # Requested by ltp team, as curl is missing after installation
    zypper_call('in curl');
}

1;
# vim: set sw=4 et:
