use strict;
use warnings;
use testapi qw(check_var get_var get_required_var);
use needle;
use File::Basename;
use scheduler 'load_yaml_schedule';
BEGIN {
    unshift @INC, dirname(__FILE__) . '/../../lib';
}
use utils;
use Utils::Architectures qw(is_aarch64);
use main_common;

init_main();

my $distri = testapi::get_required_var('CASEDIR') . '/lib/susedistribution.pm';
require $distri;
testapi::set_distribution(susedistribution->new());

sub is_regproxy_required {
    # For now only the Kubic kubeadm test needs a registry proxy.
    # docker_image and podman_image pull with the full path themselves.
    return check_var('SYSTEM_ROLE', 'kubeadm');
}

sub is_image_flavor {
    return get_required_var('FLAVOR') =~ /-Image/;
}

sub load_boot_from_dvd_tests {
    loadtest 'installation/bootloader_uefi' if (get_var("UEFI"));
    loadtest 'installation/bootloader' unless (get_var("UEFI"));
}

sub load_boot_from_disk_tests {
    # Preparation for start testing
    loadtest 'microos/disk_boot';
    loadtest 'installation/system_workarounds' if is_aarch64;
    loadtest 'microos/networking';
}

sub load_tdup_tests {
    loadtest 'transactional/tdup';
}

sub load_feature_tests {
    # Feature tests for Micro OS operating system
    loadtest 'microos/libzypp_config';
    loadtest 'microos/image_checks' if is_image_flavor;
    loadtest 'microos/one_line_checks';
    loadtest 'microos/services_enabled';
    load_transactional_role_tests;
    loadtest 'microos/journal_check';
    if (check_var 'SYSTEM_ROLE', 'kubeadm') {
        loadtest 'console/kubeadm';
    }
    elsif (check_var 'SYSTEM_ROLE', 'container-host') {
        loadtest 'containers/podman';
        loadtest 'containers/podman_image';
    }
}

sub load_rcshell_tests {
    # Tests before the YaST installation
    loadtest 'microos/rcshell_start';
    loadtest 'microos/libzypp_config';
    loadtest 'microos/one_line_checks';
}

sub load_installation_tests {
    if (check_var('HDDSIZEGB', '10')) {
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
    else {
        # Full list of installation test-modules can be found at 'main_common.pm'
        load_inst_tests unless get_var 'BOOT_HDD_IMAGE';
        load_boot_from_disk_tests;
        load_tdup_tests             if (get_var 'TDUP');
        loadtest 'console/regproxy' if is_regproxy_required;
        load_feature_tests          if (check_var 'EXTRA', 'FEATURES');
        loadtest 'shutdown/shutdown';
    }
}

#######################
# Testing starts here #
#######################
return 1 if load_yaml_schedule;

if (get_var 'STACK_ROLE') {
    load_boot_from_disk_tests;
    load_tdup_tests      if (get_var 'TDUP');
    load_feature_tests() if (check_var 'EXTRA', 'FEATURES');
    loadtest 'shutdown/shutdown';
}
else {
    load_boot_from_dvd_tests unless get_var 'BOOT_HDD_IMAGE';
    if (get_var 'SYSTEM_ROLE') {
        load_installation_tests;
    }
    elsif (check_var 'EXTRA', 'RCSHELL') {
        load_rcshell_tests;
    }
}

1;
