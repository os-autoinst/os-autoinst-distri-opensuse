# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: module loader of security tests
# Maintainer: QE Security <none@suse.de>

package main_security;
use Mojo::Base 'Exporter';
use Exporter;
use utils;
use version_utils;
use main_common qw(loadtest boot_hdd_image);
use testapi qw(get_var);
use Utils::Architectures;
use Utils::Backends;

our @EXPORT = qw(
  is_security_test
  load_security_tests
);

sub is_security_test {
    return get_var('SECURITY', 1);
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


sub load_security_tests {
    if (get_var('TEST') eq 'selinux') {
        load_selinux_tests;
    }
    elsif (get_var('TEST') eq 'container_selinux') {
        load_container_selinux_tests;
    }
    elsif (get_var('TEST') eq 'fde_misc') {
        load_fde_misc_tests;
    }
    elsif (get_var('TEST') eq 'fips_ker_mode_tests_crypt_core') {
        fips_ker_mode_tests_crypt_core;
    }
}


