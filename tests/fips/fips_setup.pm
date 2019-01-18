# Copyright © 2016-2018 SUSE LLC
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
# Summary: Setup fips mode for further testing
#          Support both "global mode" (fips=1 in kernel command line)
#          and "ENV mode" - selected by FIPS_ENV_MODE
# Maintainer: Wes <whdu@suse.com>
# Tags: poo#39071

use strict;
use warnings;
use base "consoletest";
use testapi;
use utils;

sub run {
    select_console 'root-console';

    # Disable Packagekit
    systemctl 'mask packagekit.service';
    systemctl 'stop packagekit.service';

    zypper_call('in -t pattern fips');

    # If FIPS_ENV_MODE, then set ENV for some FIPS modules. It is a
    # workaround when fips=1 kernel cmdline is not working.
    # If FIPS_ENV_MODE does not set, global FIPS mode (fips=1 from
    # kernel command line) will be applied
    if (get_var("FIPS_ENV_MODE")) {
        foreach my $env ('OPENSSL_FIPS', 'OPENSSL_FORCE_FIPS_MODE', 'LIBGCRYPT_FORCE_FIPS_MODE', 'NSS_FIPS') {
            assert_script_run "echo 'export $env=1' >> /etc/bash.bashrc";
        }
    }
    else {
        assert_script_run "sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT/s/\\(\"\\)\$/ fips=1\\1/' /etc/default/grub";
        assert_script_run "grub2-mkconfig -o /boot/grub2/grub.cfg";
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
