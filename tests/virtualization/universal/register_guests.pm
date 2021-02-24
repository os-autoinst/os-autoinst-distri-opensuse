# Copyright © 2019-2020 SUSE LLC
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
# Package: openssl SUSEConnect ca-certificates-suse
# Summary: Register all guests against local SMT server
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base "virt_feature_test_base";
use virt_autotest::common;
use strict;
use warnings;
use testapi;
use utils;
use version_utils;

sub run_test {
    my ($self) = @_;
    # Use serial terminal, unless defined otherwise. The unless will go away once we are certain this is stable
    $self->select_serial_terminal unless get_var('_VIRT_SERIAL_TERMINAL', 1) == 0;

    foreach my $guest (keys %virt_autotest::common::guests) {
        record_info "$guest", "Registrating $guest against SMT";
        my ($sles_running_version, $sles_running_sp) = get_os_release("ssh root\@$guest");
        if ($sles_running_version >= 12) {
            assert_script_run("ssh root\@$guest SUSEConnect -r " . get_var('SCC_REGCODE') . " -e " . get_var("SCC_EMAIL"));
        }
        assert_script_run("ssh root\@$guest zypper -n ref");
        # Perhaps check the return values?
        script_run("ssh root\@$guest 'zypper ar --refresh http://download.suse.de/ibs/SUSE:/CA/" . $virt_autotest::common::guests{$guest}->{distro} . "/SUSE:CA.repo'", 90);
        assert_script_run("ssh root\@$guest 'zypper -n in ca-certificates-suse'", 90);
    }
}

1;

