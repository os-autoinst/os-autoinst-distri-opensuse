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

# Summary: Do the registration against SCC after installation
# Maintainer: Yi Xu <yxu@suse.de>

use strict;
use base 'y2logsstep';

use testapi;
use utils 'sle_version_at_least';
use registration;

sub run {
    return if get_var('HDD_SCC_REGISTERED');
    my $version  = get_required_var('VERSION');
    my $arch     = get_required_var('ARCH');
    my $reg_code = get_required_var('SCC_REGCODE');
    my $scc_url  = get_required_var('SCC_URL');

    select_console 'root-console';
    assert_script_run "SUSEConnect --url $scc_url -r $reg_code";

    # add modules

    foreach (values %registration::SLE15_MODULES) {
        assert_script_run "SUSEConnect -p sle-module-" . lc($_) . "/$version/$arch";
    }
}

1;
# vim: set sw=4 et:
