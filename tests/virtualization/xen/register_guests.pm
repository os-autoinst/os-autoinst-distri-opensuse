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

sub run {
    my ($self) = @_;

    foreach my $guest (keys %xen::guests) {
        record_info "$guest", "Registrating $guest against SMT";
        assert_script_run("ssh root\@$guest 'zypper ar --refresh http://download.suse.de/ibs/SUSE:/CA/" . $xen::guests{$guest}->{distro} . "/SUSE:CA.repo'", 90);
        assert_script_run("ssh root\@$guest 'zypper -n in ca-certificates-suse'",                                            90);
        assert_script_run("ssh root\@$guest 'wget -O /tmp/clientSetup.sh http://smt.suse.de/repo/tools/clientSetup4SMT.sh'", 90);
        assert_script_run("ssh root\@$guest 'chmod +x /tmp/clientSetup.sh'");
        #TODO: Fetch the fingerprint
        assert_script_run("ssh root\@$guest '/tmp/clientSetup.sh --host smt.suse.de --fingerprint D1:31:1A:7E:8C:2A:04:DD:81:C9:23:F3:41:0F:2D:75:2F:0B:76:81 --yes'", 180);
    }
}

1;

