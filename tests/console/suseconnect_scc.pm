# SUSE openQA tests
#
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

# Summary: Register system against SCC after installation
# Maintainer: Michal Nowak <mnowak@suse.com>

use strict;
use base 'y2logsstep';

use testapi;
use utils 'zypper_call';
use version_utils 'is_sle';
use registration;

sub run {
    return if get_var('HDD_SCC_REGISTERED');
    my $reg_code   = get_required_var('SCC_REGCODE');
    my $scc_url    = get_required_var('SCC_URL');
    my $scc_addons = get_var('SCC_ADDONS', '');

    select_console 'root-console';
    assert_script_run "SUSEConnect --url $scc_url -r $reg_code";
    my $expected_suseconnect_output = 'SUSEConnect -p';
    $expected_suseconnect_output = 'transactional-update register -p' if (get_var('SYSTEM_ROLE') =~ /microos|serverro/);
    validate_script_output('SUSEConnect --list-extensions', sub { $expected_suseconnect_output });

    # add modules
    if (is_sle '15+') {
        foreach (split(',', $registration::SLE15_DEFAULT_MODULES{get_required_var('SLE_PRODUCT')} . ",$scc_addons")) {
            add_suseconnect_product("sle-module-" . lc($registration::SLE15_MODULES{$_}));
        }
    }
    # Check that repos actually work
    zypper_call('refresh');
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
