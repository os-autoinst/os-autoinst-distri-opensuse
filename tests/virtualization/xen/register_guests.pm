# Copyright (C) 2019 SUSE LLC
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
# Summary: Register all guests against local SMT server
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base "consoletest";
use xen;
use strict;
use warnings;
use testapi;
use utils;
use version_utils;

sub run {
    my ($self) = @_;

    foreach my $guest (keys %xen::guests) {
        record_info "$guest", "Registrating $guest against SMT";
        my ($sles_running_version, $sles_running_sp) = get_sles_release("ssh root\@$guest");
        if ($sles_running_version >= 12) {
            assert_script_run("ssh root\@$guest SUSEConnect -r " . get_var('SCC_REGCODE') . " -e " . get_var("SCC_EMAIL"));
        }
        assert_script_run("ssh root\@$guest zypper -n ref");
        # Perhaps check the return values?
        script_run("ssh root\@$guest 'zypper ar --refresh http://download.suse.de/ibs/SUSE:/CA/" . $xen::guests{$guest}->{distro} . "/SUSE:CA.repo'", 90);
        assert_script_run("ssh root\@$guest 'zypper -n in ca-certificates-suse'", 90);
    }
}

1;

