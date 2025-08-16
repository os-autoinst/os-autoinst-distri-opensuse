# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: module loader of security tests
# Maintainer: QE Security <none@suse.de>

package main_security;
use Mojo::Base 'Exporter';
use Exporter;
use testapi;
use utils;
use version_utils;
use main_common qw(loadtest boot_hdd_image);
use Utils::Architectures;
use Utils::Backends;

our @EXPORT = qw(
  is_security_test
  load_security_tests
);

sub is_security_test {
    return get_var('SECURITY', 0);
}

sub load_selinux_tests {
    loadtest('security/selinux/selinux_setup');
    loadtest('security/selinux/sestatus');
    loadtest('security/selinux/semanage_fcontext');
    loadtest('security/selinux/semanage_boolean');
    loadtest('security/selinux/fixfiles');
    loadtest('security/selinux/print_se_context');
    loadtest('security/selinux/audit2allow');
    loadtest('security/selinux/semodule');
    loadtest('security/selinux/setsebool');
    loadtest('security/selinux/restorecon');
    loadtest('security/selinux/chcon');
    loadtest('security/selinux/chcat');
    loadtest('security/selinux/set_get_enforce');
    loadtest('security/selinux/selinuxexeccon');
}

sub load_container_selinux_tests {
    loadtest('security/selinux/selinux_setup');
    loadtest('security/selinux/sestatus');
    loadtest('security/selinux/container_selinux');
}

sub load_fde_misc_tests {
    loadtest('security/selinux/selinux_setup');
    loadtest('security/tpm2/tpm2_verify_presence');
    loadtest('security/tpm2/tpm2_fail_key_unsealing');
    loadtest('security/fde_regenerate_key');
}

sub fips_ker_mode_tests_crypt_core {
    loadtest('security/selinux/selinux_setup');
    loadtest('fips/fips_setup');
    loadtest('fips/openssl/openssl_fips_alglist');
    loadtest('fips/openssl/openssl_fips_hash');
    loadtest('fips/openssl/openssl_fips_cipher');
    loadtest('console/openssl_alpn');
    loadtest('fips/gnutls/gnutls_base_check');
    loadtest('fips/gnutls/gnutls_server');
    loadtest('fips/gnutls/gnutls_client');
    loadtest('fips/openssl/openssl_pubkey_rsa');
    loadtest('fips/openssl/openssl_pubkey_dsa');
    loadtest('fips/openssl/openssl_fips_dhparam');
    loadtest('fips/openssh/openssh_fips');
    loadtest('console/sshd');
    loadtest('console/ssh_cleanup');
}

## main entry point
sub load_security_tests {
    if (check_var('SECURITY_TEST', 'fips_setup')) {
        load_security_tests_fips_setup();
    } elsif (check_var('SECURITY_TEST', 'crypt_core')) {
        load_security_tests_crypt_core();
    } elsif (check_var('SECURITY_TEST', 'apparmor')) {
        load_security_tests_apparmor();
    } elsif (check_var('SECURITY_TEST', 'selinux') || check_var('TEST', 'selinux')) {
        load_selinux_tests;
    } elsif (check_var('SECURITY_TEST', 'container_selinux') || check_var('TEST', 'container_selinux')) {
        load_container_selinux_tests;
    } elsif (check_var('SECURITY_TEST', 'fde_misc') || check_var('TEST', 'fde_misc')) {
        load_fde_misc_tests;
    } elsif (check_var('SECURITY_TEST', 'fips_ker_mode_tests_crypt_core') ||
        check_var('TEST', 'fips_ker_mode_tests_crypt_core')) {
        fips_ker_mode_tests_crypt_core;
    } else {
        die "Unknown SECURITY_TEST requested";
    }
}

sub load_security_console_prepare {
    loadtest "console/consoletest_setup";
    # Add this setup only in product testing
    loadtest "security/test_repo_setup" if (get_var("SECURITY_TEST") =~ /^crypt_/ && !is_opensuse && (get_var("BETA") || check_var("FLAVOR", "Online-QR")));
    loadtest "fips/fips_setup" if (get_var("FIPS_ENABLED"));
    loadtest "console/openssl_alpn" if (get_var("FIPS_ENABLED") && get_var("JEOS"));
    loadtest "console/yast2_vnc" if (get_var("FIPS_ENABLED") && is_pvm);
}

# Used by fips-jeos on o3
sub load_security_tests_crypt_core {
    load_security_console_prepare();

    if (get_var('FIPS_ENABLED')) {
        loadtest "fips/openssl/openssl_fips_alglist";
        loadtest "fips/openssl/openssl_fips_hash";
        loadtest "fips/openssl/openssl_fips_cipher";
        loadtest "fips/openssl/dirmngr_setup";
        loadtest "fips/openssl/dirmngr_daemon";    # dirmngr_daemon needs to be tested after dirmngr_setup
        loadtest "fips/gnutls/gnutls_base_check";
        loadtest "fips/gnutls/gnutls_server";
        loadtest "fips/gnutls/gnutls_client";
    }
    loadtest "fips/openssl/openssl_tlsv1_3";
    loadtest "fips/openssl/openssl_pubkey_rsa";
    # https://bugzilla.suse.com/show_bug.cgi?id=1223200#c2
    loadtest "fips/openssl/openssl_pubkey_dsa" if (is_sle('<15-SP6') || is_leap('<15.6'));
    loadtest "fips/openssh/openssh_fips" if get_var("FIPS_ENABLED");
    loadtest "console/sshd";
    loadtest "console/ssh_cleanup";
}

sub load_security_tests_fips_setup {
    # Setup system into fips mode
    loadtest "fips/fips_setup";
}

sub load_security_tests_apparmor {
    load_security_console_prepare();

    # Switch from SELinux to AppArmor if necessary
    set_var('SECURITY_MAC', 'apparmor');
    loadtest 'console/enable_mac';

    if (check_var('TEST', 'mau-apparmor') || is_jeos) {
        loadtest "security/apparmor/aa_prepare";
    }
    loadtest "security/apparmor/aa_status";
    loadtest "security/apparmor/aa_enforce";
    loadtest "security/apparmor/aa_complain";
    loadtest "security/apparmor/aa_genprof";
    loadtest "security/apparmor/aa_autodep";
    loadtest "security/apparmor/aa_logprof";
    loadtest "security/apparmor/aa_easyprof";
    loadtest "security/apparmor/aa_notify";
    loadtest "security/apparmor/aa_disable";
}
