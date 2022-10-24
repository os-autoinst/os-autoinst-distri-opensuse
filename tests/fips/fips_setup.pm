# Copyright 2016-2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: patterns-server-enterprise-fips
# Summary: Setup fips mode for further testing:
#          Installation check - verify the setup of FIPS installation
#          ENV mode - selected by FIPS_ENV_MODE
#          Global mode - setup fips=1 in kernel command line
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#39071, poo#105591, poo#105999, poo#109133

use base 'opensusebasetest';
use strict;
use warnings;
use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(quit_packagekit zypper_call reconnect_mgmt_console package_upgrade_check);
use bootloader_setup "add_grub_cmdline_settings";
use power_action_utils "power_action";
use Utils::Backends 'is_pvm';
use version_utils 'is_sle';

sub run {
    my ($self) = @_;
    select_serial_terminal;

    # For installation only. FIPS has already been setup during installation
    # (DVD installer booted with fips=1), so we only do verification here.
    if (get_var("FIPS_INSTALLATION")) {
        assert_script_run("grep '^GRUB_CMDLINE_LINUX_DEFAULT.*fips=1' /etc/default/grub");
        assert_script_run("grep '^1\$' /proc/sys/crypto/fips_enabled");
        record_info 'Kernel Mode', 'FIPS kernel mode (for global) configured!';

        # Stop packagekitd
        quit_packagekit;

        # Make sure FIPS pattern is installed and there is no conflicts.
        zypper_call("refresh");
        zypper_call("search -si -t pattern fips");

        return;
    }

    # FIPS_INSTALLATION is only applicable for system installaton
    die "FIPS_INSTALLATION is require to run this script for installation" if get_var("!BOOT_HDD_IMAGE");
    die "FIPS setup is only applicable for FIPS_ENABLED=1 image!" if get_var("!FIPS_ENABLED");

    # If FIPS_ENV_MODE, then set ENV for some FIPS modules. It is a
    # workaround when fips=1 kernel cmdline is not working.
    # If FIPS_ENV_MODE does not set, global FIPS mode (fips=1 from
    # kernel command line) will be applied
    if (get_var("FIPS_ENV_MODE")) {
        die 'FIPS kernel mode is required for this test!' if check_var('SECURITY_TEST', 'crypt_kernel');
        zypper_call('in -t pattern fips');
        foreach my $env ('OPENSSL_FIPS', 'OPENSSL_FORCE_FIPS_MODE', 'LIBGCRYPT_FORCE_FIPS_MODE', 'NSS_FIPS', 'GnuTLS_FORCE_FIPS_MODE') {
            assert_script_run "echo 'export $env=1' >> /etc/bash.bashrc";
        }

        record_info 'ENV Mode', 'FIPS environment mode (for single modules) configured!';
    }
    else {
        zypper_call('in -t pattern fips');
        add_grub_cmdline_settings('fips=1', update_grub => 1);
        record_info 'Kernel Mode', 'FIPS kernel mode configured!';
    }

    # Check if hmac related packages are installed when sle >= 15-sp4
    # Refer to poo #110707
    if (is_sle('>=15-sp4')) {
        my $pkg_list = {
            'libcryptsetup12-hmac' => '2.4.3',
            'libsoftokn3-hmac' => '3.68.3',
            'libgnutls30-hmac' => '3.7.3',
            'libfreebl3-hmac' => '3.68.3',
            'libopenssl1_1-hmac' => '1.1.1l',
            'libgcrypt20-hmac' => '1.9.4'
        };
        zypper_call("in " . join(' ', keys %$pkg_list));
        package_upgrade_check($pkg_list);
    }

    power_action('reboot', textmode => 1);
    if (is_pvm) {
        reconnect_mgmt_console;
        $self->wait_boot(textmode => 1, ready_time => 600, bootloader_time => 300);
    }
    else {
        $self->wait_boot(bootloader_time => 200);
    }

    # Workaround to resolve console switch issue
    select_serial_terminal;
    assert_script_run q(grep '^1$' /proc/sys/crypto/fips_enabled) unless (get_var('FIPS_ENV_MODE'));
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
