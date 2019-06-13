# Copyright © 2016-2019 SUSE LLC
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
# Summary: Setup fips mode for further testing:
#          Installation check - verify the setup of FIPS installation
#          ENV mode - selected by FIPS_ENV_MODE
#          Global mode - setup fips=1 in kernel command line
# Maintainer: wnereiz <wnereiz@member.fsf.org>
# Tags: poo#39071

use strict;
use warnings;
use base "consoletest";
use testapi;
use utils "zypper_call";
use bootloader_setup "add_grub_cmdline_settings";
use power_action_utils "power_action";

sub run {
    my ($self) = @_;
    select_console "root-console";

    # For installation only. FIPS has already been setup during installation
    # (DVD installer booted with fips=1), so we only do verification here.
    if (get_var("FIPS_INSTALLATION")) {
        assert_script_run("grep '^GRUB_CMDLINE_LINUX_DEFAULT.*fips=1' /etc/default/grub");
        assert_script_run("grep '^1\$' /proc/sys/crypto/fips_enabled");
        record_info 'Kernel Mode', 'FIPS kernel mode (for global) configured!';

        # Make sure FIPS pattern is installed and there is no conflicts.
        zypper_call("refresh");
        zypper_call("search -si -t pattern fips");

        return;
    }

    # FIPS_INSTALLATION is only applicable for system installaton
    die "FIPS_INSTALLATION is require to run this script for installation" if get_var("!BOOT_HDD_IMAGE");
    die "FIPS setup is only applicable for FIPS_ENABLED=1 image!"          if get_var("!FIPS_ENABLED");

    # If FIPS_ENV_MODE, then set ENV for some FIPS modules. It is a
    # workaround when fips=1 kernel cmdline is not working.
    # If FIPS_ENV_MODE does not set, global FIPS mode (fips=1 from
    # kernel command line) will be applied
    if (get_var("FIPS_ENV_MODE")) {
        die 'FIPS kernel mode is required for this test!' if check_var('SECURITY_TEST', 'crypt_kernel');
        zypper_call('in -t pattern fips');
        foreach my $env ('OPENSSL_FIPS', 'OPENSSL_FORCE_FIPS_MODE', 'LIBGCRYPT_FORCE_FIPS_MODE', 'NSS_FIPS') {
            assert_script_run "echo 'export $env=1' >> /etc/bash.bashrc";
        }

        record_info 'ENV Mode', 'FIPS environment mode (for single modules) configured!';
    }
    else {
        zypper_call('in -t pattern fips');
        add_grub_cmdline_settings('fips=1', 1);
        record_info 'Kernel Mode', 'FIPS kernel mode configured!';
    }

    power_action('reboot', textmode => 1);
    $self->wait_boot;

    # Workaround to resolve console switch issue
    select_console 'root-console';
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
