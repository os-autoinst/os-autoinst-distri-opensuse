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

# Summary: Do the registration against SCC after installation
# Maintainer: Yi Xu <yxu@suse.de>

use strict;
use base "y2logsstep";

use testapi;
use registration;

sub run {
    if (!get_var("HDD_SCC_REGISTERED")) {

	# add repo
        script_run "zypper ar -f http://download.suse.de/ibs/SUSE:/SLE-15:/GA/standard/SUSE:SLE-15:GA.repo";
        script_run "zypper in sles-release";
        script_run "zypper rr 1";

	# fix simlink
	script_run "rm /etc/products.d/baseproduct";
	script_run "ln -s SLES.prod /etc/products.d/baseproduct";

	# activate base SLES15
	assert_script_run "SUSEConnect -r 30452ce234918d23";
	script_run "SUSEConnect --list-extensions";

	# add modules
	assert_script_run "SUSEConnect -p sle-module-basesystem/15/x86_64";
	assert_script_run "SUSEConnect -p sle-module-scripting/15/x86_64";
	assert_script_run "SUSEConnect -p sle-module-desktop-applications/15/x86_64";
	assert_script_run "SUSEConnect -p sle-module-development-tools/15/x86_64";
	assert_script_run "SUSEConnect -p sle-module-server-applications/15/x86_64";
	assert_script_run "SUSEConnect -p sle-module-legacy/15/x86_64";
    }
}

1;
# vim: set sw=4 et:
