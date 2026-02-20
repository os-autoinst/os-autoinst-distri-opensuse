# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Setup fips mode for further testing:
#          Installation check - verify the setup of FIPS after installation
#          ENV mode - selected by FIPS_ENV_MODE
#          Kernel mode - setup fips=1 in kernel command line
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#39071, poo#105591, poo#105999, poo#109133

use base 'consoletest';
use testapi;
use bootloader_setup qw(add_grub_cmdline_settings change_grub_config);
use power_action_utils 'power_action';
use transactional qw(trup_call process_reboot);
use utils qw(zypper_call reconnect_mgmt_console);
use serial_terminal 'select_serial_terminal';
use Utils::Backends 'is_pvm';
use Utils::Architectures qw(is_aarch64 is_ppc64le is_s390x);
use version_utils qw(is_jeos is_sle_micro is_sle is_tumbleweed is_transactional is_microos);
use security::vendoraffirmation;
use security::certification;

my @vars = ('OPENSSL_FIPS', 'OPENSSL_FORCE_FIPS_MODE', 'LIBGCRYPT_FORCE_FIPS_MODE', 'NSS_FIPS', 'GNUTLS_FORCE_FIPS_MODE');

sub reboot_and_login {
    my $self = shift;

    is_transactional ? process_reboot(trigger => 1) : power_action('reboot', textmode => 1, keepconsole => is_pvm);
    reconnect_mgmt_console if is_pvm;
    $self->wait_boot if !is_transactional;
    is_ppc64le() ? select_console('root-console') : select_serial_terminal();
    return;
}

sub enable_fips {
    my $self = shift;

    if (is_sle('>=15-SP4') || is_jeos || is_tumbleweed) {
        assert_script_run("fips-mode-setup --enable", timeout => 120);
        $self->reboot_and_login;
    } else {
        # on SL Micro 6.0+ we only need to reboot, no need to manually change grub.
        if (is_sle_micro('<6.0')) {
            change_grub_config('=\"[^\"]*', '& fips=1 ', 'GRUB_CMDLINE_LINUX_DEFAULT');
            trup_call('--continue grub.cfg');
        } else {
            add_grub_cmdline_settings('fips=1', update_grub => 1) unless (is_sle_micro || is_microos);
        }
        $self->reboot_and_login;
    }
    return;
}

sub ensure_fips_enabled {
    if (is_sle('>=15-SP4') || is_jeos || is_tumbleweed || is_microos) {
        validate_script_output("fips-mode-setup --check",
            sub { m/FIPS mode is enabled\.\n.*\nThe current crypto policy \(FIPS\) is based on the FIPS policy\./ });
    } else {
        assert_script_run q(grep '^1$' /proc/sys/crypto/fips_enabled);
        assert_script_run("grep '^GRUB_CMDLINE_LINUX_DEFAULT.*fips=1' /etc/default/grub");
    }
    return;
}

sub install_fips {
    if (is_transactional) {
        if (is_sle_micro('<6.0')) {
            trup_call("pkg install -t pattern microos-fips");
        } else {
            trup_call("setup-fips");
        }
        # crypto-policies script reports Cannot handle transactional systems.
    } elsif (((is_sle('>=15-SP4') || is_jeos || is_tumbleweed)) && !get_var("FIPS_ENV_MODE")) {
        zypper_call("in crypto-policies-scripts");
        # Explicitly install openssl-3 on s390x SLE16 https://bugzilla.suse.com/show_bug.cgi?id=1247463
        zypper_call("in openssl-3") if (is_s390x && is_sle('>=16'));
        install_vendor_affirmation_pkgs if (check_var('FIPS_USE_CERT_MODULE', '1') && is_sle('=15-SP7'));
    } elsif (is_sle('<=15-SP3') || get_var("FIPS_ENV_MODE")) {
        # No crypto-policies in older SLE
        zypper_call("in -t pattern fips");
        # When using FIPS in env mode on >= 15-SP6, we need the command
        # update-crypto-policies, otherwise some tests will fail.
        zypper_call("in crypto-policies-scripts") if is_sle('>=15-SP6');
        # Test Certification module on 15-SP7 only
        if (check_var('FIPS_USE_CERT_MODULE', '1') && is_sle('=15-SP7')) {
            install_certification_pkgs;
            check_installed_certification_pkgs;
        }
    }
    return;
}

sub run {
    my ($self) = @_;

    is_ppc64le() ? select_console('root-console') : select_serial_terminal();

    # For installation only. FIPS has already been setup during installation
    # (DVD installer booted with fips=1), so we only do verification here.
    if (get_var("FIPS_INSTALLATION")) {
        install_fips;
        ensure_fips_enabled;
        record_info 'Kernel Mode', 'FIPS kernel mode (for global) configured!';
        return;
    }

    if (get_var("FIPS_ENV_MODE")) {
        die 'FIPS kernel mode is required for this test!' if check_var('SECURITY_TEST', 'crypt_kernel');
        install_fips;

        env_bashrc();

        if (is_sle('>=15-SP6')) {
            env_systemd();
            assert_script_run "update-crypto-policies --set FIPS";
        }

        $self->reboot_and_login;
        record_info 'ENV Mode', 'FIPS environment mode (for single modules) configured!';
    } else {
        install_fips;
        $self->enable_fips;
        ensure_fips_enabled;
    }
    return;
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

# create a systemd config file for env vars
sub env_systemd {
    my $cfg_file = '/etc/systemd/system.conf.d/enable-fips-mode.conf';
    my $content = "[Manager]\n";
    $content .= "DefaultEnvironment=";
    foreach my $var (@vars) {
        $content .= "\"$var=1\" ";
    }
    $content .= "\n";
    assert_script_run qq(echo "$content" > $cfg_file);
    return;
}

# add env vars to bashrc
sub env_bashrc {
    my $content = '';
    foreach my $var (@vars) {
        $content .= "export $var=1\n";
    }
    assert_script_run qq(echo "$content" >> /etc/bash.bashrc);
    return;
}

1;
