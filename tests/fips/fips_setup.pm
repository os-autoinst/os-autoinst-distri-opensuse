# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Setup fips mode for further testing:
#          Installation check - verify the setup of FIPS after installation
#          ENV mode - selected by FIPS_ENV_MODE
#          Kernel mode - setup fips=1 in kernel command line
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#39071, poo#105591, poo#105999, poo#109133

use base qw(consoletest opensusebasetest);
use strict;
use warnings;
use testapi;
use bootloader_setup 'add_grub_cmdline_settings';
use power_action_utils 'power_action';
use serial_terminal 'select_serial_terminal';
use transactional qw(trup_call process_reboot);
use utils qw(zypper_call reconnect_mgmt_console);
use Utils::Backends 'is_pvm';
use version_utils qw(is_alp is_jeos is_sle is_tumbleweed);

sub reboot_and_select_serial_term {
    my $self = shift;

    is_alp ? process_reboot(trigger => 1) : power_action('reboot', textmode => 1, keepconsole => is_pvm);
    reconnect_mgmt_console if is_pvm;
    $self->wait_boot;
    select_serial_terminal;
}

sub run {
    my ($self) = @_;

    select_serial_terminal;

    # For installation only. FIPS has already been setup during installation
    # (DVD installer booted with fips=1), so we only do verification here.
    if (get_var("FIPS_INSTALLATION")) {
        assert_script_run("grep '^GRUB_CMDLINE_LINUX_DEFAULT.*fips=1' /etc/default/grub");
        assert_script_run("grep '^1\$' /proc/sys/crypto/fips_enabled");
        record_info 'Kernel Mode', 'FIPS kernel mode (for global) configured!';
        return;
    }

    # FIPS_INSTALLATION is only applicable for system installaton
    die "FIPS_INSTALLATION is require to run this script for installation" if get_var("!BOOT_HDD_IMAGE");
    die "FIPS setup is only applicable for FIPS_ENABLED=1 image!" if get_var("!FIPS_ENABLED");

    if (get_var("FIPS_ENV_MODE")) {
        die 'FIPS kernel mode is required for this test!' if check_var('SECURITY_TEST', 'crypt_kernel');
        is_alp ? trup_call("pkg install -t pattern fips") : zypper_call('in -t pattern fips');
        foreach my $env ('OPENSSL_FIPS', 'OPENSSL_FORCE_FIPS_MODE', 'LIBGCRYPT_FORCE_FIPS_MODE', 'NSS_FIPS', 'GnuTLS_FORCE_FIPS_MODE') {
            assert_script_run "echo 'export $env=1' >> /etc/bash.bashrc";
        }
        $self->reboot_and_select_serial_term;
        record_info 'ENV Mode', 'FIPS environment mode (for single modules) configured!';
    } else {
        zypper_call("in crypto-policies-scripts") if (is_sle('>=15-SP4') || is_jeos || is_tumbleweed);
        trup_call("pkg install -t pattern fips") if is_alp;
        zypper_call("in -t pattern fips") if is_sle('<=15-SP3');

        $self->reboot_and_select_serial_term if (is_alp || is_jeos);

        if (is_sle('>=15-SP4') || is_jeos || is_tumbleweed) {
            assert_script_run("fips-mode-setup --enable");
            $self->reboot_and_select_serial_term;
            validate_script_output("fips-mode-setup --check", sub { m/FIPS mode is enabled\.\n.*\nThe current crypto policy \(FIPS\) is based on the FIPS policy\./ });
        } else {
            add_grub_cmdline_settings('fips=1', update_grub => 1);
            $self->reboot_and_select_serial_term;
            assert_script_run q(grep '^1$' /proc/sys/crypto/fips_enabled);
        }
    }
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
