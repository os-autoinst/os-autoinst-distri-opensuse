# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: module loader for JeOS (Minimal-VM) tests
# Maintainer: qa-c@suse.de

package main_jeos;
use Mojo::Base 'Exporter';
use main_common;
use main_containers qw(load_container_tests is_container_test);
use version_utils qw(is_sle is_opensuse);
use testapi;
use utils;
use Utils::Architectures;
use Utils::Backends;

our @EXPORT = qw(
  load_jeos_tests
);

sub load_jeos_boot_tests {
    my $machine = get_required_var('MACHINE');

    loadtest 'installation/bootloader_svirt' if is_svirt;
    loadtest 'installation/bootloader_uefi' if ($machine =~ /xen-hvm|hyperv$|vmware/);

    loadtest 'jeos/firstrun';
    loadtest 'console/verify_efi_mok' if check_var('UEFI', '1');

    if (check_var('FIRST_BOOT_CONFIG', 'cloud-init') {
        loadtest 'installation/first_boot';
        loadtest 'console/system_prepare';
    } else {
        loadtest 'jeos/firstrun';
    }
}

sub load_common_tests {
    loadtest 'jeos/image_info' if (get_var('POSTGRES_IP'));
    loadtest 'jeos/record_machine_id';
    loadtest 'console/force_scheduled_tasks';
    loadtest 'jeos/grub2_gfxmode'; # this test case also disables grub timeout
    loadtest 'jeos/diskusage';
    loadtest 'jeos/build_key';
    loadtest 'console/prjconf_excluded_rpms';
    loadtest 'microos/libzypp_config';
    if (is_sle) {
        loadtest 'console/suseconnect_scc';
        loadtest 'jeos/efi_tid' if (get_var('UEFI') && is_sle('=12-sp5'));
        loadtest 'qa_automation/patch_and_reboot' if is_updates_tests;
    } elsif (is_opensuse) {
        replace_opensuse_repos_tests if is_repo_replacement_required;
    }    
}

sub load_journal_check_tests {
    # Enclosing test cases
    loadtest 'console/journal_check';
    loadtest 'shutdown/shutdown';
}


sub load_basic_tests {
    loadtest 'console/textinfo';
    loadtest 'console/hostname';r
    loadtest 'console/ping';
    loadtest 'locale/keymap_or_locale';
    loadtest 'console/orphaned_packages_check';
    loadtest 'console/systemd_wo_udev';
    loadtest 'console/sshd_running';
    loadtest 'console/sshd';
    loadtest 'console/ssh_cleanup';
    loadtest 'jeos/glibc_locale';
    loadtest 'jeos/kiwi_templates';
}
    
sub load_zypper_tests {
    loadtest 'console/zypper_lr';
    loadtest 'console/zypper_in';
    loadtest 'console/zypper_log_packages';
    loadtest 'console/zypper_lifecycle';
    loadtest 'console/zypper_lr_validate';
    loadtest 'console/zypper_ref';
    loadtest 'console/zypper_extend';
}

sub load_yast_tests {
    loadtest 'console/yast2_lan';
    loadtest 'console/yast2_i';
    loadtest 'console/yast2_bootloader';
    loadtest 'console/yast2_lan_device_settings';
    loadtest 'console/';
}

sub load_app_tests {
    loadtest 'console/curl_https';
    loadtest 'console/http_srv';
    loadtest 'console/nginx';
    loadtest 'console/apache';
    loadtest 'console/apache_ssl';
    loadtest 'console/apache_nss';
    loadtest 'console/shibboleth';
    loadtest 'console/mariadb_srv';
    loadtest 'console/mariadb_odbc';
    loadtest 'console/postgresql_server';
    loadtest 'console/sqlite3';
    loadtest 'console/salt';
}

sub load_jeos_main_tests {
    load_basic_tests();
    load_zypper_tests();
    #...

}

sub load_jeos_extra_tests {
    load_app_tests();
    #...
}


sub load_jeos_openstack_tests {
    return unless is_openstack;
    my $args = OpenQA::Test::RunArgs->new();
    loadtest 'boot/boot_to_desktop';
    if (get_var('JEOS_OPENSTACK_UPLOAD_IMG')) {
        loadtest "publiccloud/upload_image";
        return;
    } else {
        loadtest "jeos/prepare_openstack", run_args => $args;
    }

    if (get_var('LTP_COMMAND_FILE')) {
        loadtest 'publiccloud/run_ltp';
        return;
    } else {
        loadtest 'publiccloud/ssh_interactive_start', run_args => $args;
    }

    if (get_var('CI_VERIFICATION')) {
        loadtest 'jeos/verify_cloudinit', run_args => $args;
        loadtest("publiccloud/ssh_interactive_end", run_args => $args);
        return;
    }

    loadtest "jeos/image_info" if get_var('POSTGRES_IP');
    loadtest "jeos/record_machine_id";
    loadtest "console/system_prepare" if is_sle;
    loadtest "console/force_scheduled_tasks";
    loadtest "jeos/grub2_gfxmode";
    loadtest "jeos/build_key";
    loadtest "console/prjconf_excluded_rpms";
    unless (get_var('CI_VERIFICATION')) {
        loadtest "console/suseconnect_scc";
    }
    unless (get_var('CONTAINER_RUNTIME')) {
        loadtest "console/journal_check";
        loadtest "microos/libzypp_config";
    }

    loadtest 'qa_automation/patch_and_reboot' if is_updates_tests;
    replace_opensuse_repos_tests if is_repo_replacement_required;
    main_containers::load_container_tests();
    loadtest("publiccloud/ssh_interactive_end", run_args => $args);
}



# Main test loader
sub load_jeos_tests {
    if (is_openstack) {
        load_jeos_openstack_tests();
        return;
    }
    load_jeos_boot_tests;

    if (is_kernel_test) {
        load_kernel_tests;
        return;
    }
    if (is_container_test) {
        load_container_tests;
        return;
    }
    load_common_tests;

    if (check_var('EXTRA', 'main')) {
        load_jeos_main_tests;
    } elsif (check_var('EXTRA', 'extra')) {
        load_jeos_extra_tests;
    } elsif (check_var('EXTRA', 'fips')) {
        load_security_tests_crypt_core;
    }
    load_journal_check_tests;
}

1;
