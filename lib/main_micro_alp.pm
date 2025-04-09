# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: module loader for MicroOS, SLE Micro and Leap Micro.
# Maintainer: qa-c@suse.de

package main_micro_alp;
use strict;
use warnings;
use base 'Exporter';
use Exporter;
use main_common;
use main_ltp_loader 'load_kernel_tests';
use main_containers qw(load_container_tests is_container_test load_container_engine_test);
use main_publiccloud qw(load_publiccloud_download_repos);
use main_security qw(load_security_tests is_security_test);
use testapi qw(check_var get_required_var get_var set_var record_info);
use version_utils;
use utils;
use Utils::Architectures;
use Utils::Backends;
use Data::Dumper;


sub is_image {
    return get_required_var('FLAVOR') =~ /image|default|kvm|base/i;
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
    loadtest 'console/suseconnect_scc' if (get_var('SCC_REGISTER') && !is_dvd);
    loadtest 'transactional/install_updates' if (is_sle_micro && is_released);
}

sub load_boot_from_disk_tests {
    return if is_ppc64le && get_var('MACHINE') !~ /ppc64le-emu/i && !(is_sle_micro('=5.5') && check_var('FLAVOR', 'Container-Image-Updates'));
    # add additional image handling module for svirt workers
    if (is_s390x()) {
        loadtest 'installation/bootloader_start';
    } elsif (is_vmware()) {
        loadtest 'installation/bootloader_svirt';
        loadtest 'installation/bootloader_uefi';
    }

    # read FIRST_BOOT_CONFIG in order to know how the image will be configured
    # ignition|combustion|ignition+combustion is considered as default path
    if (check_var('FIRST_BOOT_CONFIG', 'wizard')) {
        loadtest 'installation/bootloader_uefi' unless is_vmware || is_s390x || is_bootloader_sdboot;
        loadtest 'jeos/firstrun';
    } elsif (check_var('FIRST_BOOT_CONFIG', 'cloud-init')) {
        unless (is_s390x) {
            loadtest 'installation/bootloader_uefi' unless is_vmware;
            loadtest 'installation/first_boot';
        }
        loadtest 'jeos/verify_cloudinit';
    } else {
        if (is_s390x()) {
            loadtest 'boot/boot_to_desktop';
        } elsif (is_vmware) {
            loadtest 'installation/first_boot';
        } else {
            loadtest 'microos/disk_boot';
        }
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
    loadtest 'installation/disable_grub_timeout' if is_bootloader_grub2;
    loadtest 'installation/configure_bls' if is_bootloader_sdboot || is_bootloader_grub2_bls;
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
    if (check_var('FIRST_BOOT_CONFIG', 'wizard')) {
        loadtest 'jeos/firstrun';
    }
    replace_opensuse_repos_tests if is_repo_replacement_required;
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
    loadtest 'microos/image_checks' if (is_image || is_selfinstall);
    loadtest 'microos/one_line_checks';
    loadtest 'microos/services_enabled';
    # MicroOS -old images use wicked, but cockpit-wicked is no longer supported in TW
    loadtest 'microos/cockpit_service' unless (is_microos('Tumbleweed') && is_staging) || (is_microos('Tumbleweed') && get_var('HDD_1', '') =~ /-old/) || !get_var('SCC_REGISTER');
    loadtest 'console/perl_bootloader' unless (is_bootloader_sdboot || is_bootloader_grub2_bls);
    # Staging has no access to repos and the MicroOS-DVD does not contain ansible
    # Ansible test needs Packagehub in SLE and it can't be enabled in SLEM
    loadtest 'console/ansible' unless (is_staging || is_sle_micro || is_leap_micro);
    loadtest 'console/salt' unless (is_staging || is_sle_micro);
    # On s390x zvm setups we need more time to wait for system to boot up.
    # Skip this test with sd-boot. The reason is not what you'd think though:
    # With sd-boot, host_config does not perform a reboot and a snapshot is made while the serial terminal
    # is logged in. year_2038_detection does a forced rollback to this snapshot and triggers poo#109929,
    # breaking most later modules.
    loadtest 'console/year_2038_detection' unless (is_s390x || is_sle_micro || is_leap_micro || is_bootloader_sdboot);
}


sub load_transactional_tests {
    loadtest 'transactional/disable_timers';
    loadtest 'transactional/filesystem_ro';
    loadtest 'transactional/trup_smoke';
    loadtest 'microos/patterns' if is_sle_micro;
    loadtest 'transactional/transactional_update';
    loadtest 'transactional/rebootmgr';
    loadtest 'transactional/health_check' if is_bootloader_grub2;    # health-checker needs GRUB2 (poo#129748)
}


sub load_network_tests {
    loadtest 'microos/networking';
    loadtest 'microos/networkmanager';
    loadtest 'microos/libzypp_config';
    loadtest 'console/firewalld';
}

sub load_qemu_tests {
    loadtest 'microos/rebuild_initrd' if is_s390x;
    loadtest 'qemu/info';
    loadtest 'qemu/qemu' unless is_rt;
    loadtest 'qemu/kvm' unless (is_aarch64 or is_ppc64le or is_rt);
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
    # https://bugzilla.suse.com/show_bug.cgi?id=1223200#c2
    loadtest 'fips/openssl/openssl_pubkey_dsa' if is_sle_micro('<6.0');
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
    loadtest 'security/selinux/selinux_smoke';
    loadtest 'security/selinux/enforcing_mode_setup';
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
    if (get_var('PUBLIC_CLOUD_AZURE_AITL')) {
        loadtest "publiccloud/azure_aitl", run_args => $args;
    } elsif (get_var('PUBLIC_CLOUD_DOWNLOAD_TESTREPO')) {
        load_publiccloud_download_repos();
    } elsif (get_var('PUBLIC_CLOUD_UPLOAD_IMG')) {
        loadtest("boot/boot_to_desktop");
        loadtest("publiccloud/upload_image");
    } else {
        # SLEM basic test
        loadtest("boot/boot_to_desktop");
        loadtest("publiccloud/prepare_instance", run_args => $args);
        loadtest("publiccloud/registration", run_args => $args);
        # 2 next modules of pubcloud needed for sle-micro incidents/repos verification
        if (get_var('PUBLIC_CLOUD_QAM', 0)) {
            loadtest("publiccloud/transfer_repos", run_args => $args);
            loadtest("publiccloud/patch_and_reboot", run_args => $args);
        }
        if (get_var('PUBLIC_CLOUD_LTP', 0)) {
            loadtest("publiccloud/run_ltp", run_args => $args);
        } elsif (get_var('PUBLIC_CLOUD_AISTACK')) {
            # AISTACK test verification
            loadtest("publiccloud/ssh_interactive_start", run_args => $args);
            loadtest("publiccloud/create_aistack_env", run_args => $args);
            loadtest("publiccloud/aistack_rbac_run", run_args => $args);
            loadtest("publiccloud/aistack_sanity_run", run_args => $args);
            loadtest("publiccloud/ssh_interactive_end", run_args => $args);
        } elsif (is_container_test) {
            loadtest("publiccloud/ssh_interactive_start", run_args => $args);
            loadtest("publiccloud/instance_overview", run_args => $args);
            loadtest("publiccloud/slem_prepare", run_args => $args);
            my $runtime = get_required_var('CONTAINER_RUNTIMES');
            for (split(',\s*', $runtime)) {
                my $run_args = OpenQA::Test::RunArgs->new();
                $run_args->{runtime} = $_;
                load_container_engine_test($run_args);
            }
            loadtest("publiccloud/ssh_interactive_end", run_args => $args);
        } else {
            loadtest "publiccloud/check_services", run_args => $args;
            loadtest("publiccloud/slem_basic", run_args => $args);
        }
    }
}

sub load_xfstests_tests {
    if (check_var('XFSTESTS', 'installation')) {
        load_boot_from_disk_tests;
        loadtest 'transactional/host_config';
        loadtest 'console/suseconnect_scc';
        loadtest 'xfstests/install';
        unless (check_var('NO_KDUMP', '1')) {
            loadtest 'xfstests/enable_kdump';
        }
        loadtest 'shutdown/shutdown';
    }
    else {
        boot_hdd_image;
        loadtest 'xfstests/partition';
        loadtest 'xfstests/run';
    }
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

    if (get_var('XFSTESTS')) {
        load_xfstests_tests;
        return 1;
    }

    if (get_var('BTRFS_PROGS')) {
        boot_hdd_image;
        loadtest 'btrfs-progs/install';
        loadtest 'btrfs-progs/run';
        loadtest 'btrfs-progs/generate_report';
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
    } elsif (is_pvm && is_sle_micro('>=6.1')) {
        loadtest 'installation/bootloader';
        loadtest 'microos/install_image';
    } elsif (is_selfinstall) {
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
    } elsif (is_security_test) {
        load_security_tests;
    } elsif (check_var('EXTRA', 'networking')) {
        load_network_tests;
    } elsif (check_var('EXTRA', 'provisioning')) {
        # verify_setup is not working correctly in microos with ignition
        # for the initial configuration. Disabled temporarily to investigate!
        loadtest 'microos/verify_setup' unless check_var('FIRST_BOOT_CONFIG', 'ignition') && is_microos;
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
    load_journal_check_tests;
}

1;
