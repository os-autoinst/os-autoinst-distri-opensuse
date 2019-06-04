use strict;
use warnings;
use testapi qw(check_var get_var get_required_var);
use needle;
use File::Basename;
BEGIN {
    unshift @INC, dirname(__FILE__) . '/../../lib';
}
use utils;
use main_common;

init_main();

my $distri = testapi::get_required_var('CASEDIR') . '/lib/susedistribution.pm';
require $distri;
testapi::set_distribution(susedistribution->new());

sub load_boot_from_dvd_tests {
    loadtest 'installation/bootloader_uefi' if (get_var("UEFI"));
    loadtest 'installation/bootloader' unless (get_var("UEFI"));
}

sub load_boot_from_disk_tests {
    # Preparation for start testing
    loadtest 'microos/disk_boot';
    loadtest 'microos/networking';
    loadtest 'microos/repositories';
}

sub load_feature_tests {
    # Feature tests for Micro OS operating system
    loadtest 'caasp/create_autoyast' unless check_var('VIRSH_VMM_FAMILY', 'hyperv');
    loadtest 'caasp/libzypp_config';
    loadtest 'caasp/one_line_checks';
    loadtest 'caasp/services_enabled';
    load_transactional_role_tests;
    loadtest 'caasp/journal_check';
    if (check_var 'SYSTEM_ROLE', 'kubeadm') {
        loadtest 'console/kubeadm';
    }
    elsif (check_var 'SYSTEM_ROLE', 'container-host') {
        loadtest 'console/podman';
    }
}

sub load_rcshell_tests {
    # Tests before the YaST installation
    loadtest 'caasp/rcshell_start';
    loadtest 'caasp/libzypp_config';
    loadtest 'caasp/one_line_checks';
}

sub load_installation_tests {
    if (check_var('HDDSIZEGB', '10')) {
        # boo#1099762
        # undefined method "safe_copy" for nil:NilClass
        # YaST2 crashes if disk is too small for a viable proposal
        loadtest('installation/welcome');
        loadtest('installation/installation_mode');
        loadtest('installation/logpackages');
        loadtest('installation/system_role');
        loadtest('installation/user_settings_root');
        loadtest('installation/installation_overview');
    }
    else {
        # Full list of installation test-modules can be found at 'main_common.pm'
        load_inst_tests;
        load_boot_from_disk_tests;
        load_feature_tests if (check_var 'EXTRA', 'FEATURES');
        loadtest 'shutdown/shutdown';
    }
}

#######################
# Testing starts here #
#######################
if (get_var 'STACK_ROLE') {
    load_boot_from_disk_tests;
    load_feature_tests() if (check_var 'EXTRA', 'FEATURES');
    loadtest 'shutdown/shutdown';
}
else {
    load_boot_from_dvd_tests;
    if (get_var 'SYSTEM_ROLE') {
        load_installation_tests;
    }
    elsif (check_var 'EXTRA', 'RCSHELL') {
        load_rcshell_tests;
    }
}

1;
