# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: module loader for MicroOS, SLE Micro, Leap Micro and ALP.
# Maintainer: qa-c@suse.de

package main_micro_alp;
use strict;
use warnings;
use base 'Exporter';
use Exporter;
use main_common;
use main_containers qw(load_container_tests is_container_test);
use testapi qw(check_var get_required_var get_var set_var);
use version_utils;
use utils;
use Utils::Architectures;
use Utils::Backends;

sub is_image {
    return get_required_var('FLAVOR') =~ /image|default|kvm/i;
}

sub is_dvd {
    return get_required_var('FLAVOR') =~ /dvd/i;
}

sub is_regproxy_required {
    # For now only the Kubic kubeadm test needs a registry proxy.
    # docker_image and podman_image pull with the full path themselves.
    return check_var('SYSTEM_ROLE', 'kubeadm');
}

sub load_config_tests {
    loadtest 'transactional/tdup' if get_var('TDUP');
    loadtest 'transactional/host_config' unless is_dvd;
    loadtest 'rt/rt_is_realtime' if is_rt;
    loadtest 'transactional/enable_selinux' if (get_var('ENABLE_SELINUX') && is_image);
    loadtest 'console/suseconnect_scc' if (is_sle_micro && get_var('SCC_REGISTER') && !is_dvd);
    loadtest 'transactional/install_updates' if (is_sle_micro && is_released);
}

sub load_boot_from_disk_tests {
    loadtest 'installation/bootloader_start' if is_s390x();
    if (check_var('FIRST_BOOT_CONFIG', 'wizard')) {
        loadtest 'jeos/firstrun';
    } elsif (is_s390x()) {
        loadtest 'boot/boot_to_desktop';
    } else {
        loadtest 'microos/disk_boot';
    }

    loadtest 'installation/system_workarounds' if (is_aarch64 && is_microos);
    replace_opensuse_repos_tests if is_repo_replacement_required;
}

sub load_boot_from_dvd_tests {
    if (is_s390x) {
        loadtest 'installation/bootloader_start';
    } elsif (get_var('UEFI')) {
        loadtest 'installation/bootloader_uefi';
    } else {
        loadtest 'installation/bootloader';
    }
}

sub load_10GB_installation_tests {
    # boo#1099762
    # undefined method "safe_copy" for nil:NilClass
    # YaST2 crashes if disk is too small for a viable proposal
    loadtest 'installation/welcome';
    loadtest 'installation/installation_mode';
    loadtest 'installation/logpackages';
    loadtest 'installation/system_role';
    loadtest 'installation/ntp_config_settings';
    loadtest 'installation/user_settings_root';
    loadtest 'installation/installation_overview';
}

sub load_installation_tests {
    loadtest 'installation/welcome';
    loadtest 'installation/disk_activation' if is_zvm;
    loadtest 'installation/scc_registration' if is_sle_micro;
    if (is_microos) {
        loadtest 'installation/online_repos';
        loadtest 'installation/installation_mode';
        loadtest 'installation/logpackages';
        loadtest 'installation/system_role';
    }

    loadtest 'installation/ntp_config_settings';
    loadtest 'installation/user_settings_root';
    loadtest 'installation/resolve_dependency_issues';
    if (get_var('PATTERNS')) {
        loadtest 'installation/select_patterns';
        loadtest 'installation/installation_overview';
        loadtest 'installation/edit_optional_kernel_cmd_parameters' if get_var('PATTERNS') =~ m/fips/i;
    } else {
        loadtest 'installation/installation_overview';
    }
    loadtest 'installation/disable_grub_timeout';
    loadtest 'installation/enable_selinux' if get_var('ENABLE_SELINUX');
    loadtest 'installation/start_install';
    loadtest 'installation/await_install';
    loadtest 'installation/logs_from_installation_system';
    loadtest 'installation/reboot_after_installation';
    if (is_s390x) {
        loadtest 'boot/reconnect_mgmt_console';
        loadtest 'installation/first_boot';
    } else {
        loadtest 'microos/disk_boot';
    }
    loadtest 'console/textinfo';
    replace_opensuse_repos_tests if is_repo_replacement_required;
}

sub load_autoyast_installation_tests {
    loadtest 'autoyast/prepare_profile' if get_var('AUTOYAST_PREPARE_PROFILE');
    loadtest 'installation/bootloader_start';
    loadtest 'autoyast/installation';
    loadtest 'autoyast/console';
    loadtest 'autoyast/login';
    loadtest 'autoyast/logs';
    loadtest 'console/textinfo';
}

sub load_selfinstall_boot_tests {
    loadtest 'installation/bootloader_uefi';
    loadtest 'microos/selfinstall';
}

sub load_remote_target_tests {
    loadtest 'installation/bootloader_start';
    loadtest 'remote/remote_target';
    loadtest 'console/textinfo';
    loadtest 'microos/networking';
    loadtest 'microos/libzypp_config';
    loadtest 'microos/one_line_checks';
    loadtest 'microos/services_enabled';
    loadtest 'console/journal_check';
    loadtest 'shutdown/shutdown';
}

sub load_remote_controller_tests {
    loadtest 'support_server/login';
    loadtest 'support_server/setup';
    loadtest 'remote/remote_controller';
    loadtest 'installation/welcome';
    if (is_sle_micro) {
        loadtest 'installation/scc_registration';
    } elsif (is_microos) {
        loadtest 'installation/online_repos';
        loadtest 'installation/installation_mode';
        loadtest 'installation/system_role';
    }
    loadtest 'installation/ntp_config_settings';
    loadtest 'installation/user_settings_root';
    loadtest 'installation/resolve_dependency_issues';
    loadtest 'installation/installation_overview';
    loadtest 'installation/disable_grub_timeout';
    loadtest 'installation/start_install';
    loadtest 'installation/await_install';
    loadtest 'installation/reboot_after_installation';
    loadtest 'support_server/wait_children';
}

sub load_common_tests {
    loadtest 'console/regproxy' if is_regproxy_required;
    loadtest 'microos/networking';
    loadtest 'microos/libzypp_config';
    loadtest 'microos/image_checks' if is_image;
    loadtest 'microos/one_line_checks';
    loadtest 'microos/services_enabled';
    # MicroOS -old images use wicked, but cockpit-wicked is no longer supported in TW
    loadtest 'microos/cockpit_service' unless is_staging || (is_microos('Tumbleweed') && get_var('HDD_1') =~ /-old/);
    # Staging has no access to repos and the MicroOS-DVD does not contain ansible
    # Ansible test needs Packagehub in SLE and it can't be enabled in SLEM
    loadtest 'console/ansible' unless (is_staging || is_sle_micro || is_leap_micro || is_alp);
    loadtest 'console/kubeadm' if (check_var('SYSTEM_ROLE', 'kubeadm'));
}


sub load_transactional_tests {
    loadtest 'transactional/filesystem_ro';
    loadtest 'transactional/trup_smoke';
    loadtest 'microos/patterns' if is_sle_micro;
    loadtest 'transactional/transactional_update';
    loadtest 'transactional/rebootmgr';
    loadtest 'transactional/health_check';
}


sub load_network_tests {
    loadtest 'microos/networking';
    loadtest 'microos/networkmanager';
    loadtest 'microos/libzypp_config';
    # This method is only loaded in ALP
    loadtest 'console/firewalld';
}

sub load_qemu_tests {
    loadtest 'microos/rebuild_initrd' if is_s390x;
    loadtest 'qemu/info';
    loadtest 'qemu/qemu';
    loadtest 'qemu/kvm' unless is_aarch64;
    # qemu-linux-user package not available in SLEM
    loadtest 'qemu/user' unless (is_sle_micro || is_leap_micro);
}

sub load_fips_tests {
    loadtest 'transactional/enable_fips' if get_var('BOOT_HDD_IMAGE');
    loadtest 'fips/libica' if is_s390x && is_sle_micro('5.4+');
    loadtest 'fips/openssl/openssl_fips_alglist';
    loadtest 'fips/openssl/openssl_fips_cipher';
    loadtest 'fips/openssl/openssl_fips_dhparam';
    loadtest 'fips/openssl/openssl_fips_hash';
    loadtest 'fips/openssl/openssl_pubkey_dsa';
    loadtest 'fips/openssl/openssl_pubkey_rsa';
    loadtest 'fips/gnutls/gnutls_base_check';
    loadtest 'fips/gnutls/gnutls_server';
    loadtest 'fips/gnutls/gnutls_client';
    loadtest 'console/gpg';
    # Need to investigate why this doesn't work in MicroOS
    loadtest 'fips/mozilla_nss/nss_smoke' unless is_microos;
}

sub load_selinux_tests {
    loadtest 'security/selinux/selinux_setup';
    loadtest 'security/selinux/sestatus';
    # ALP has selinux enabled and in enforcing mode by default
    loadtest 'security/selinux/selinux_smoke' unless is_alp;
    loadtest 'security/selinux/enforcing_mode_setup' unless is_alp;
    loadtest 'security/selinux/semanage_fcontext';
    loadtest 'security/selinux/semanage_boolean';
    loadtest 'security/selinux/fixfiles';
    loadtest 'security/selinux/print_se_context';
    loadtest 'security/selinux/audit2allow';
    loadtest 'security/selinux/semodule';
    loadtest 'security/selinux/setsebool';
    loadtest 'security/selinux/restorecon';
    loadtest 'security/selinux/chcon';
    loadtest 'security/selinux/chcat';
    loadtest 'security/selinux/set_get_enforce';
    loadtest 'security/selinux/selinuxexeccon';
}


sub load_rcshell_tests {
    # Tests before the YaST installation
    loadtest 'microos/rcshell_start';
    loadtest 'microos/libzypp_config';
    loadtest 'microos/one_line_checks';
}

sub load_journal_check_tests {
    # Enclosing test cases
    loadtest 'console/journal_check';
    loadtest 'shutdown/shutdown';
}

sub load_slem_on_pc_tests {
    my $args = OpenQA::Test::RunArgs->new();

    loadtest("boot/boot_to_desktop");
    loadtest("publiccloud/prepare_instance", run_args => $args);
    loadtest("publiccloud/registration", run_args => $args);
    loadtest("publiccloud/ssh_interactive_start", run_args => $args);
    loadtest("publiccloud/instance_overview", run_args => $args);
    loadtest("publiccloud/slem_prepare", run_args => $args);

    if (get_var("PUBLIC_CLOUD_CONTAINERS")) {
        load_container_tests() if is_container_test;
    }
    loadtest("publiccloud/ssh_interactive_end", run_args => $args);
}

sub load_tests {
    # SLEM on PC
    if (is_public_cloud()) {
        load_slem_on_pc_tests;
        return 1;
    }

    if (is_kernel_test()) {
        load_kernel_tests;
        return 1;
    }

    if (get_var('REMOTE_TARGET')) {
        load_remote_target_tests;
        return 1;
    }
    if (get_var('REMOTE_CONTROLLER')) {
        load_remote_controller_tests;
        return 1;
    }

    if (get_var('BOOT_HDD_IMAGE')) {
        load_boot_from_disk_tests;
    } elsif (get_var('SELFINSTALL')) {
        load_selfinstall_boot_tests;
    } elsif (get_var('AUTOYAST')) {
        load_autoyast_installation_tests;
    } elsif (check_var 'EXTRA', 'RCSHELL') {
        load_boot_from_dvd_tests;
        load_rcshell_tests;
        return 1;
    } elsif (is_dvd) {
        load_boot_from_dvd_tests;
        if (check_var('HDDSIZEGB', '10')) {
            load_10GB_installation_tests;
            return;    # in 10G-disk tests, we don't run more tests
        }
        load_installation_tests;
        # Stop here if we are testing only scc extensions (live, phub, ...) activation
        my $is_phub = get_var('SCC_ADDONS');
        if (defined($is_phub) && $is_phub =~ /phub/) {
            loadtest 'transactional/check_phub';
            return;
        }
    }

    load_config_tests;

    if (is_container_test || check_var('SYSTEM_ROLE', 'container-host')) {
        if (is_microos) {
            # MicroOS Container-Host image runs all tests.
            load_common_tests;
            load_transactional_tests;
        }
        load_container_tests;
        # Container tests didn't execute journal check. However, if doing so, there
        # are some errors to be investigated. We need to remove this return;
        return 1;
    } elsif (check_var('EXTRA', 'networking')) {
        load_network_tests;
    } elsif (check_var('EXTRA', 'provisioning')) {
        # This module fails in MicroOS, never been run before. Need to investigate.
        loadtest 'microos/verify_setup' unless is_microos;
        load_transactional_tests;
    } elsif (check_var('EXTRA', 'virtualization')) {
        load_qemu_tests;
    } elsif (check_var('EXTRA', 'fips')) {
        load_fips_tests;
    } elsif (check_var('EXTRA', 'selinux')) {
        load_selinux_tests;
    } else {
        load_common_tests;
        load_transactional_tests unless is_zvm;
    }
    loadtest 'console/year_2038_detection';
    load_journal_check_tests;
}

1;
